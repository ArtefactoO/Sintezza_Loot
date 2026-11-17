local now, inside, grouped, map, difficulty, secret = 1000, true, true, 109, 1, {}
local character = "Player-1-ABC"
function GetServerTime() return now end
function GetLocale() return "enUS" end
function UnitGUID(unit) if unit == "player" then return character end end
function IsInGroup() return grouped end
function GetInstanceInfo()
    return inside and "Sunken Temple" or "Outside", inside and "party" or "none", difficulty, nil, nil, nil, nil, map
end
function UnitClass() return "Priest", "PRIEST" end
function InCombatLockdown() return true end
RAID_CLASS_COLORS = { PRIEST = {}, WARRIOR = {} }
INSTANCE_RESET_SUCCESS = "%s has been reset."
Sintezza_Theme = { GetLocale = GetLocale }
assert(loadfile(ADDON_ROOT .. "/../Sintezza_Theme/DataTransfer.lua"))("Sintezza_Theme", Sintezza_Theme)

local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
function FreshHistory(db, reload)
    local ns = {
        db = db or { rollHistory = {} }, events = {}, Settings = {},
        IsSecretValue = function(value) return value == secret end,
        DataTracker = { ROLL_TYPE_PENDING = -1 },
        RosterInspector = {
            GetUnitNames = function() return "Tester" end,
            GetShortName = function(_, name) return name end,
        },
    }
    function ns:RegisterEvent(event, callback) self.events[event] = callback end
    assert(loadfile(ADDON_ROOT .. "/Locales.lua"))("Sintezza_Loot", ns)
    assert(loadfile(ADDON_ROOT .. "/RunHistory.lua"))("Sintezza_Loot", ns)
    assert(loadfile(ADDON_ROOT .. "/RunEvidence.lua"))("Sintezza_Loot", ns)
    assert(loadfile(ADDON_ROOT .. "/Data.lua"))("Sintezza_Loot", ns)
    ns.History:Init()
    ns.History:ObserveInstance(false, reload)
    return ns, ns.History
end

local function begin(H)
    local id, run, visit = H:GetRollRunID()
    return { historyRunID = id, historyRun = run, historyVisit = visit, historyStartedAt = now,
        itemName = "Test item", itemLink = "|Hitem:123:0|h[Test item]|h", players = {}, allPassed = true }
end
local function zone(ns, value)
    inside = value
    now = now + 60
    ns.events.PLAYER_ENTERING_WORLD()
end

local ns, H = FreshHistory()
assert(count(ns.db.lootRuns) == 0 and #H:FindRuns("") == 0)
assert(not next(ns.db.activeLootRuns) and not next(ns.db.lootRunPresence))
local runID = H.insideRunID
local simulated = begin(H); simulated.isSimulated = true; H:Record(simulated)
assert(not next(ns.db.lootRuns) and #ns.db.rollHistory == 0)
zone(ns, false); zone(ns, true)
assert(H.insideRunID == runID and not next(ns.db.lootRuns))
local first = begin(H)
assert(not next(ns.db.lootRuns), "unfinished roll must not persist its run")
H:Record(first)
assert(count(ns.db.lootRuns) == 1 and #H:FindRuns("") == 1)
assert(ns.db.activeLootRuns[character] == runID)
assert(#H:FindRuns("missing item") == 0)
assert(#H:FindRuns("sunken") == 1)
print("PASS: empty visits, unfinished/simulated rolls, first completed roll and search")

ns.events.ENCOUNTER_END("ENCOUNTER_END", 42, "Boss", 1, 5, 0)
zone(ns, false)
UnitIsGhost = function() return true end
zone(ns, true)
assert(H.insideRunID == runID)
UnitIsGhost = function() return false end
zone(ns, false); zone(ns, true)
assert(H.insideRunID == runID)
assert(not ns.events.PLAYER_TARGET_CHANGED, "NPC GUIDs must not split runs")
local saved = ns.db
ns, H = FreshHistory(saved)
assert(H.insideRunID == runID and H:GetActiveRun().id == runID)
difficulty = secret; H:ObserveInstance(); difficulty = 1; H:ObserveInstance()
-- A withheld difficulty must not turn into a different run.
assert(H.insideRunID == runID)
print("PASS: wipe, ghost and living returns, reload, unknown difficulty")

zone(ns, false)
ns.events.CHAT_MSG_SYSTEM("CHAT_MSG_SYSTEM", "Other dungeon has been reset.")
zone(ns, true); assert(H.insideRunID == runID)
zone(ns, false)
ns.events.CHAT_MSG_SYSTEM("CHAT_MSG_SYSTEM", INSTANCE_RESET_SUCCESS:format("Sunken Temple"))
zone(ns, true); assert(H.insideRunID ~= runID)
assert(count(ns.db.lootRuns) == 1, "new empty run must not enter archive")
local second = begin(H); H:Record(second)
assert(count(ns.db.lootRuns) == 2)
map = 230; H:ObserveInstance(); assert(H.insideRunID ~= second.historyRunID)
local before = H.insideRunID
difficulty = 2; H:ObserveInstance(); assert(H.insideRunID ~= before)
before = H.insideRunID
ns.events.CHALLENGE_MODE_START(); assert(H.insideRunID ~= before)
before = H.insideRunID
ns.events.CHALLENGE_MODE_RESET(); H:ObserveInstance(); assert(H.insideRunID ~= before)
before = H.insideRunID
zone(ns, false); ns.events.CHALLENGE_MODE_RESET(); zone(ns, true); assert(H.insideRunID ~= before)
before = H.insideRunID
zone(ns, false); ns.events.CHALLENGE_MODE_START(); zone(ns, true); assert(H.insideRunID ~= before)
before = H.insideRunID
grouped = false; ns.events.GROUP_LEFT(); H:ObserveInstance(); assert(H.insideRunID ~= before)
grouped, map, difficulty = true, 109, 1
print("PASS: confirmed reset, map/difficulty change, challenges and group departure")

ns, H = FreshHistory()
local delayed = begin(H)
ns.events.CHALLENGE_MODE_COMPLETED()
assert(not next(ns.db.lootRuns))
zone(ns, false); map = 230; zone(ns, true)
collectgarbage("collect")
H:Record(delayed)
assert(ns.db.lootRuns[delayed.historyRunID].endReason == "completed")
assert(ns.db.rollHistory[1].runID == delayed.historyRunID)
assert(H.insideRunID ~= delayed.historyRunID)
assert(not ns.db.activeLootRuns[character], "late result must not reactivate old run")
local current = begin(H); H:Record(current)
H:RemoveRolls(function(entry) return entry == current.historyEntry end)
assert(not ns.db.lootRuns[current.historyRunID])
local currentAgain = begin(H); H:Record(currentAgain)
assert(currentAgain.historyRunID == current.historyRunID)
assert(ns.db.lootRuns[current.historyRunID])
H:Record(current)
assert(#ns.db.rollHistory == 2, "removed rolls must not return")
print("PASS: late loot after completion/zone change, clearing and continuing a run")

local old = {
    rollHistory = { { time = 500, runID = 7, name = "Kept", character = character } },
    lootRuns = {
        [7] = { id = 7, name = "Old", mapID = 109, kind = "party", difficulty = 1, startedAt = 400, character = character },
        [8] = { id = 8, name = "Empty", mapID = 109, kind = "party", difficulty = 1, startedAt = 600, character = character },
    },
    activeLootRuns = { [character] = 8 }, lootRunPresence = { [character] = 8 },
    lootAttemptCarry = { [character] = { [123] = 6 } },
}
ns, H = FreshHistory(old)
assert(count(old.lootRuns) == 1 and old.lootRuns[7] and #old.rollHistory == 1)
assert(old.lootAttemptCarry[character][123] == 6)
H:Init(); assert(count(old.lootRuns) == 1)
local fresh = begin(H); H:Record(fresh)
assert(fresh.historyRunID > 8)
print("PASS: idempotent old-data cleanup keeps rolls, attempt counts and IDs")

ns, H = FreshHistory()
local captured = begin(H)
for i = 1, 401 do
    local s = begin(H); s.historyStartedAt = now + i; H:Record(s)
end
assert(#ns.db.rollHistory == 400 and count(ns.db.lootRuns) == 1)
assert(ns.db.lootAttemptCarry[character][123] == 1)
local rows = assert(ns.DataTransferSpec.export("all"))
local exportedCount = #rows
local importNS, importH = FreshHistory()
local plan = assert(importNS.DataTransferSpec.stage(rows))
assert(plan.added == exportedCount)
assert(importNS.DataTransferSpec.apply(plan))
assert(#importNS.db.rollHistory == 400 and count(importNS.db.lootRuns) == 1)
local duplicate = assert(importNS.DataTransferSpec.stage(rows))
assert(duplicate.added == 0)
local runOnly = { rows[1] }
local emptyNS = FreshHistory()
local emptyPlan = assert(emptyNS.DataTransferSpec.stage(runOnly))
assert(emptyPlan.added == 0 and #emptyPlan.runs == 0 and emptyPlan.message)
emptyNS.DataTransferSpec.apply(emptyPlan)
assert(not next(emptyNS.db.lootRuns))
print("PASS: 400-roll retention, CSV round trip, duplicates and run-only import")
