local secret = {}

local function NewTracker(db)
    local time, historyClock = 500, 1500
    local timers, events, records = {}, {}, {}
    local drops, historyTimeReads = {}, 0
    local trackerUI = { refreshes = 0 }
    function trackerUI:Refresh() self.refreshes = self.refreshes + 1 end
    function trackerUI:HideWindow() self.hidden = true end
    local ns = {
        db = db,
        L = {},
        IsSecretValue = function(value) return value == secret end,
        GetItemInfo = function(link) return link end,
        History = {
            character = "Player-test",
            GetRollRunID = function() return 9 end,
            Record = function(_, session) records[#records + 1] = session end,
        },
        RosterInspector = { GetEligibleGroupMembers = function() return {} end },
        RollTrackerFrame = trackerUI,
        RegisterEvent = function(_, key, callback) events[key] = callback end,
    }
    local env = setmetatable({
        GetTime = function() return time end,
        GetServerTime = function() return 1700000000 + time end,
        GetLootRollItemLink = function() return "item:Native" end,
        C_Timer = { After = function(delay, callback) timers[#timers + 1] = { time + delay, callback } end },
        C_LootHistory = {
            GetLootHistoryTime = function() historyTimeReads = historyTimeReads + 1; return historyClock end,
            GetSortedDropsForEncounter = function() return drops end,
            GetSortedInfoForDrop = function(_, key)
                for _, drop in ipairs(drops) do
                    if drop.lootListKey == key then return drop end
                end
            end,
            GetAllEncounterInfos = function() return { { encounterID = 1 } } end,
        },
    }, { __index = _G })
    env._G = env
    setfenv(assert(loadfile(ADDON_ROOT .. "/DataTracker.lua")), env)("Sintezza_Loot", ns)
    local tracker = ns.DataTracker
    tracker:Init()
    local context = { tracker = tracker, drops = drops, records = records, ui = trackerUI }
    function context:Update(key)
        if key then events.LOOT_HISTORY_UPDATE_DROP(nil, 1, key)
        else events.LOOT_HISTORY_UPDATE_ENCOUNTER(nil, 1) end
    end
    function context:Advance(seconds)
        time = time + seconds
        historyClock = historyClock + seconds
        local pending = timers
        timers = {}
        for _, timer in ipairs(pending) do
            if timer[1] <= time then timer[2]()
            else timers[#timers + 1] = timer end
        end
    end
    function context:Start(id, duration) events.START_LOOT_ROLL(nil, id, duration) end
    function context:ReadCount() return historyTimeReads end
    return context
end

local function Drop(key, start, duration, link)
    return { lootListKey = key, itemHyperlink = link or ("item:" .. key), startTime = start, duration = duration, rollInfos = {} }
end

local saved = { dismissedHistoryRolls = { invalid = "bad", expired = 1 } }
local ctx = NewTracker(saved)
ctx.drops[1] = Drop(1, 1000, 60)
ctx.drops[2] = Drop(2, 1480, nil)
ctx.drops[3] = Drop(3, secret, 60)
ctx.drops[4] = Drop(4, 1440, 60)
ctx:Update()
ctx:Update(4)
assert(#ctx.tracker:GetActiveRolls() == 0 and not ctx.tracker:GetCurrentRollSession(), "Expired or undated rows must not open a roll")
assert(next(saved.dismissedHistoryRolls) == nil, "Old/invalid dismissal fields are pruned on load")
assert(ctx:ReadCount() == 2, "Read the history clock once per pass")

local active = Drop(5, 1490, 45)
ctx.drops[5] = active
ctx:Update(5)
local first = assert(ctx.tracker:GetCurrentRollSession())
assert(ctx.tracker:GetRollTimeLeft(first) == 35)
ctx.tracker:DismissRoll(first.rollID)
ctx:Update()
assert(not ctx.tracker:GetCurrentRollSession() and ctx.ui.hidden)
assert(next(saved.dismissedHistoryRolls), "Persist dismissals only for identified rolls")

local reloaded = NewTracker(saved)
reloaded.drops[1] = active
reloaded:Update()
assert(not reloaded.tracker:GetCurrentRollSession() and #reloaded.tracker:GetActiveRolls() == 0,
    "Reload must not display the same dismissed history drop")
local id = reloaded.tracker:GetLastRollID()
reloaded.tracker:UndismissRoll(id)
assert(reloaded.tracker:GetCurrentRollSession().rollID == id and not next(saved.dismissedHistoryRolls))
local refreshes = reloaded.ui.refreshes
reloaded:Advance(35)
assert(not reloaded.tracker:GetCurrentRollSession() and not reloaded.tracker:GetLastRollID())
assert(reloaded.ui.refreshes == refreshes + 1, "Expiry refreshes the UI without a loot event")
active.allPassed = true
reloaded:Update(5)
assert(#reloaded.records == 1 and reloaded.records[1].allPassed and not reloaded.tracker:GetCurrentRollSession(),
    "Record late completion without reopening the expired tab")

local replacement = Drop(5, 1532, 45, "item:Replacement")
reloaded.drops[1] = replacement
reloaded:Update(5)
assert(reloaded.tracker:GetCurrentRollSession().itemLink == "item:Replacement",
    "A new drop reusing a history key gets a new session")

local native = NewTracker({})
native.drops[1] = Drop(9, 1000, 60, "item:Native")
native:Start(10, 30000)
local real = assert(native.tracker:GetCurrentRollSession())
assert(real.rollID == 10 and not real.dropKey, "An old entry cannot claim a matching active item")
native.drops[1] = Drop(9, 1495, 35, "item:Native")
native:Update(9)
assert(real.dropKey and #native.tracker:GetActiveRolls() == 1)
native:Advance(34)
assert(native.tracker:GetCurrentRollSession() == real, "Allow a short grace period for the direct roll result")
native:Advance(1)
assert(not native.tracker:GetCurrentRollSession())
native.drops[1].allPassed = true
native:Update(9)
assert(native.records[1] == real and native.records[1].historyRunID == 9)

local historyFirst = NewTracker({})
historyFirst.drops[1] = Drop(11, 1497, 33, "item:Native")
historyFirst:Update(11)
local fromHistory = assert(historyFirst.tracker:GetCurrentRollSession())
historyFirst.tracker:DismissRoll(fromHistory.rollID)
historyFirst:Start(12, 30000)
assert(historyFirst.tracker:GetRollSession(12) == fromHistory and fromHistory.rollID == 12)
assert(not historyFirst.tracker:GetCurrentRollSession(), "A native start for the same drop must keep its dismissal")
historyFirst.tracker:UndismissRoll(12)
assert(#historyFirst.tracker:GetActiveRolls() == 1, "History and native events must not create duplicate tabs")
print("PASS: expired history, dismissal across reload, item identity, timeout and late confirmed results")
