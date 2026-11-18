local function noop() end
local secret = {}

local function FreshRoster(units, raid, party)
    local calls = { names = 0, classes = 0, roles = 0 }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.UNKNOWNOBJECT = "Unknown"
    env.UnitExists = function(unit) return units[unit] ~= nil end
    env.UnitFullName = function(unit)
        calls.names = calls.names + 1
        local record = units[unit]
        return record.first, record.last
    end
    env.UnitName = function(unit)
        local record = units[unit]
        return record.fallbackFirst, record.fallbackLast
    end
    env.UnitClass = function(unit)
        calls.classes = calls.classes + 1
        return "", units[unit].class
    end
    env.UnitGroupRolesAssigned = function(unit)
        calls.roles = calls.roles + 1
        return units[unit].role
    end
    env.IsInRaid = function() return raid end
    env.IsInGroup = function() return party end
    local ns = { IsForever = true, L = { ROSTER_UNKNOWN_PLAYER = "Unknown player" },
        IsSecretValue = function(value) return value == secret end }
    local chunk = assert(loadfile(ADDON_ROOT .. "/RosterInspector.lua"))
    setfenv(chunk, env)("Sintezza_Loot", ns)
    return ns.RosterInspector, calls
end

local units = {
    player = { first = "Ada", last = "Sage", class = "PRIEST", role = "HEALER" },
    party1 = { first = "Bryn", last = "Vale", class = "WARRIOR", role = "DAMAGER" },
    party2 = { first = "Cora", last = "Sky", class = secret, role = secret },
    party3 = { first = "Unknown", class = "MAGE", role = "DAMAGER" },
}
local roster, calls = FreshRoster(units, false, true)
local members = roster:GetEligibleGroupMembers()
assert(#members == 3)
assert(members[1].name == "Ada Sage" and members[1].fullName == "Ada-Sage")
assert(members[2].name == "Bryn Vale" and members[2].class == "WARRIOR")
assert(members[3].name == "Cora Sky" and members[3].class == nil and members[3].role == "NONE")
assert(roster:GetShortName("Bryn-Vale-Realm") == "Bryn Vale")
assert(roster:GetPlayerInfo("Bryn").name == "Bryn Vale")
assert(calls.names == 4 and calls.classes == 3 and calls.roles == 3,
    "Eligible roster should read each unit once, including unavailable names")
units.player.role = "NONE"
units.party1.class = secret
members = roster:GetEligibleGroupMembers()
assert(members[1].role == "NONE" and members[2].class == nil)
assert(roster:GetPlayerInfo("Ada Sage").role == "HEALER", "Historical cached role remains available")
assert(roster:GetPlayerInfo("Bryn Vale").class == "WARRIOR", "Secret updates keep the cached known class")
print("PASS: one-pass roster, full-name aliases, secret values and cached metadata")

local raidUnits = { player = units.player, raid1 = units.player, raid2 = units.party1 }
roster, calls = FreshRoster(raidUnits, true, true)
members = roster:GetEligibleGroupMembers()
assert(#members == 2 and members[1].name == "Ada Sage" and members[2].name == "Bryn Vale")
assert(calls.names == 3 and calls.classes == 3 and calls.roles == 3)
roster, calls = FreshRoster({ player = units.player }, false, false)
members = roster:GetEligibleGroupMembers()
assert(#members == 1 and calls.names == 1)
local fallback = { player = { first = secret, fallbackFirst = "Faye", fallbackLast = "Bright",
    class = "MAGE", role = "DAMAGER" } }
roster = FreshRoster(fallback, false, false)
assert(roster:GetEligibleGroupMembers()[1].name == "Faye Bright")
print("PASS: raid self deduplication, solo roster and readable-name fallback")

local methods = {}
local function widget() return setmetatable({ shown = true }, { __index = methods }) end
function methods:SetWidth(value) self.width = value end
function methods:SetTexture(value) self.texture = value end
function methods:SetText(value) self.text = value end
function methods:SetBackdropBorderColor(...) self.borderColor = { ... } end
function methods:SetShown(shown) self.shown = shown end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
methods.SetDesaturated, methods.SetAlpha, methods.SetTextColor, methods.Raise = noop, noop, noop, noop
local ns = {
    Theme = { PaintButton = noop }, L = { ITEM_FALLBACK = "Item" },
    db = { enabled = true, autoOpen = true },
    TrackerAppearance = { ApplyTo = noop }, RollEffects = { NewItem = noop },
    GetItemQualityColor = function() return 1, 1, 1 end,
}
local selected, dismissed, evaluations, evaluated = 2, false, {}, {}
local sessions = {
    { rollID = 1, itemName = "One", players = {} },
    { rollID = 2, itemName = "Two", players = {} },
    { rollID = 3, itemName = "Three", players = {} },
}
local tracker = {
    ROLL_TYPE_PASS = 0, ROLL_TYPE_NEED = 1, ROLL_TYPE_GREED = 2,
    ROLL_TYPE_DISENCHANT = 3, ROLL_TYPE_PENDING = -1, ROLL_ICONS = {},
}
ns.DataTracker = tracker
function tracker:GetCurrentRollSession() return sessions[selected] end
function tracker:GetActiveRolls() return sessions end
function tracker:IsDismissed() return dismissed end
function tracker:EvaluateSession(session)
    evaluations[session.rollID] = (evaluations[session.rollID] or 0) + 1
    local result = { players = {}, totalPlayers = 3, answeredPlayers = session.rollID }
    evaluated[session.rollID] = result
    return result
end
local env = setmetatable({
    Sintezza_Theme = { CreateWidgets = function() return {} end },
}, { __index = _G })
env._G = env
local chunk = assert(loadfile(ADDON_ROOT .. "/UI/RollTrackerFrame.lua"))
setfenv(chunk, env)("Sintezza_Loot", ns)
local view = ns.RollTrackerFrame
view.frame = widget()
view.frame.tabs = {}
for i = 1, 6 do
    local tab = widget()
    tab.icon, tab.badge, tab.selected = widget(), widget(), widget()
    view.frame.tabs[i] = tab
end
view.frame.itemIcon, view.frame.itemBorder, view.frame.itemTitle = widget(), widget(), widget()
view.UpdateFooter = noop
view.UpdatePlayerRows = function(self)
    assert(self.currentEval == evaluated[selected], "Player rows use this refresh's selected evaluation")
end
view:Refresh(false)
assert(evaluations[1] == 1 and evaluations[2] == 1 and evaluations[3] == 1,
    "A multi-item refresh should evaluate the current roll once")
assert(view.frame.tabs[2].badge.text == "2/3")
assert(view.frame.tabs[2].borderColor[4] == .9 and view.frame.tabs[2].selected.shown)
assert(not view.frame.tabs[1].selected.shown)
selected = 1
view:Refresh(false)
assert(evaluations[1] == 2 and evaluations[2] == 2 and evaluations[3] == 2)
assert(view.currentEval == evaluated[1] and view.frame.footerSession == sessions[1])
assert(view.frame.tabs[1].selected.shown and not view.frame.tabs[2].selected.shown)
sessions = { sessions[1] }
view:Refresh(false)
assert(evaluations[1] == 3, "A single-item refresh still evaluates its player list")
view.frame.shown, ns.db.autoOpen = false, false
view:Refresh(false)
assert(evaluations[1] == 3, "Closed non-auto-open tracker does no evaluation")
view:Refresh(true)
assert(evaluations[1] == 4)
dismissed = true
view:Refresh(true)
assert(evaluations[1] == 4, "Dismissed rolls do no evaluation")
dismissed = false
sessions = {}
for i = 1, 7 do sessions[i] = { rollID = i, itemName = tostring(i), players = {} } end
selected = 7
view:Refresh(true)
assert(evaluations[7] == 1 and view.currentEval == evaluated[7],
    "A selected roll outside the six visible tabs still evaluates once")
ns.db.enabled = false
view:Refresh(true)
assert(evaluations[7] == 1, "Disabled real tracker does no evaluation")
sessions[7].isSimulated = true
view:Refresh(false)
assert(evaluations[7] == 2, "Simulation remains available when live tracking is disabled")
sessions[7].winner = { choice = tracker.ROLL_TYPE_GREED }
view:Refresh(false)
assert(view.frame.itemBorder.borderColor[4] == .9)
sessions[7].winner, sessions[7].allPassed = nil, true
view:Refresh(false)
assert(view.frame.itemBorder.borderColor[4] == .9)
print("PASS: one evaluation per visible roll, tab switching, single-item and hidden/dismissed tracker paths")
