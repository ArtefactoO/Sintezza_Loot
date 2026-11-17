local state, secret = {}, {}
local function ResetState()
    state = { now = 200000, inside = true, map = 109, difficulty = 1, combat = false, locks = {}, requests = 0 }
end
function GetServerTime() return state.now end
function GetInstanceInfo()
    return state.inside and "Temple" or "Outside", state.inside and "party" or "none",
        state.difficulty, nil, 5, nil, nil, state.map
end
function InCombatLockdown() return state.combat end
function RequestRaidInfo() state.requests = state.requests + 1 end
function GetNumSavedInstances() return #state.locks end
function GetSavedInstanceInfo(index)
    local row = state.locks[index]
    return "Temple", row.low, 6000, row.difficulty or 1, row.locked, false, row.high or 0,
        false, 5, "Normal", row.total or 2, row.completed or 0, false, row.map or 109
end
function GetInstanceLockTimeRemaining()
    return 60, false, state.total or 0, state.completed or 0
end
function GetInstanceLockTimeRemainingEncounter(index)
    local boss = (state.bosses or {})[index] or {}
    return boss[1], nil, boss[2]
end
C_ChallengeMode, C_EncounterJournal, EJ_GetEncounterInfoByIndex = nil, nil, nil

local function Fixture(db, reload)
    local ns, H = FreshHistory(db, reload)
    ns.IsSecretValue = function(value) return value == secret end
    return ns, H
end
local function Event(ns, name, ...) return ns.events[name](name, ...) end
local function Move(ns, inside, elapsed)
    state.inside, state.now = inside, state.now + (elapsed or 1)
    Event(ns, "PLAYER_ENTERING_WORLD", false, false)
end
local function Session(H, name)
    local id, run, visit = H:GetRollRunID()
    return { historyRunID = id, historyRun = run, historyVisit = visit, historyStartedAt = state.now,
        itemName = name or "Item", itemLink = "|Hitem:123:0|h[Item]|h", players = {}, allPassed = true }
end
local function Drop(H, name)
    local session = Session(H, name)
    H:Record(session)
    return session
end
local function Progress(ns, bosses, completed)
    state.bosses, state.total, state.completed = bosses, #bosses, completed
    Event(ns, "INSTANCE_LOCK_START")
end

ResetState()
local ns, H = Fixture()
local first = Drop(H)
local original = first.historyEntry.runID
Event(ns, "ENCOUNTER_END", 1, "Boss one", 1, 5, 0)
Move(ns, false)
Move(ns, true, 86400 * 3)
assert(H.insideRunID == original, "even a multi-day unfinished return has no timeout")
assert(Drop(H).historyEntry.runID == original)
Move(ns, false)
Event(ns, "CHAT_MSG_SYSTEM", "Temple has been reset.")
Move(ns, true)
local resetID = H.insideRunID
assert(resetID ~= original)
assert(not ns.db.lootRuns[resetID], "reset alone does not save an empty run")
Move(ns, false)
Event(ns, "CHAT_MSG_SYSTEM", "Failed to reset Temple.")
Move(ns, true)
assert(H.insideRunID == resetID)
INSTANCE_RESET_SUCCESS = "Обновлено подземелье %1$s."
Move(ns, false); Event(ns, "CHAT_MSG_SYSTEM", "Обновлено подземелье Temple."); Move(ns, true)
assert(H.insideRunID ~= resetID)
INSTANCE_RESET_SUCCESS = "%s has been reset."
print("PASS: unlimited wipe return, immediate successful reset and failed/localized resets")

ResetState(); ns, H = Fixture()
first = Drop(H)
original = H.insideRunID
Event(ns, "LFG_COMPLETION_REWARD")
assert(ns.db.lootRuns[original].endReason == "completed")
local trash = Drop(H, "Trash after all bosses")
local late = Session(H, "Late trash result")
assert(trash.historyEntry.runID == original and H.insideRunID == original)
local saved = ns.db
ns, H = Fixture(saved, true)
assert(H.insideRunID == original, "reload inside finished instance must retain it")
assert(Drop(H, "Trash after reload").historyEntry.runID == original)
ns, H = Fixture(ns.db)
assert(H.insideRunID == original, "reconnecting inside without an observed exit must keep finished-run trash")
Move(ns, false)
state.now = state.now + 86400
ns, H = Fixture(ns.db)
Move(ns, true)
assert(H.insideRunID ~= original, "finished exit and tomorrow's entry must start another run")
H:Record(late)
assert(late.historyEntry.runID == original)
assert(Drop(H, "New visit").historyEntry.runID == H.insideRunID)
print("PASS: finished-run trash, reload, next-day entry and delayed results stay correctly assigned")

ResetState(); ns, H = Fixture()
first = Drop(H, "Before leaving")
H:RequestLockInfo()
state.locks = { { low = 11, locked = true } }
Event(ns, "UPDATE_INSTANCE_INFO")
assert(H:GetActiveRun().lockoutKey == "0:11")
Move(ns, false); Move(ns, true, 3)
local returning = Drop(H, "Before lock reply")
local pending = Session(H, "After lock reply")
Event(ns, "BOSS_KILL", 21, "Current visit boss")
local visitID = H.visit.id
state.locks = { { low = 22, locked = true } }
Event(ns, "UPDATE_INSTANCE_INFO")
assert(H.insideRunID ~= first.historyEntry.runID)
assert(returning.historyEntry.runID == H.insideRunID and returning.historyEntry.visitID == visitID)
assert(ns.db.lootRuns[first.historyEntry.runID].endReason == "reset")
assert(not ns.db.lootRuns[first.historyEntry.runID].killedEncounters[21])
assert(H:GetActiveRun().killedEncounters[21] and H:GetActiveRun().killedBossNames["Current visit boss"])
H:Record(pending)
assert(pending.historyEntry.runID == H.insideRunID)
local stable = H.insideRunID
Event(ns, "UPDATE_INSTANCE_INFO"); assert(H.insideRunID == stable)
assert(first.historyEntry.runID ~= returning.historyEntry.runID)
print("PASS: changed lockout reassigns only this visit, including already recorded and pending rolls")

Move(ns, false); Move(ns, true)
returning = Drop(H, "Return before reload")
saved, visitID = ns.db, H.visit.id
ns, H = Fixture(saved, true)
assert(H.visit.id == visitID)
H:RequestLockInfo()
state.locks = { { low = 33, locked = true } }
Event(ns, "UPDATE_INSTANCE_INFO")
assert(H.insideRunID ~= stable and returning.historyEntry.runID == H.insideRunID)
assert(first.historyEntry.runID ~= H.insideRunID)
print("PASS: reload preserves visit attribution for a later lockout response")

local unsupported = {
    {}, { { low = 99, locked = false } }, { { low = secret, locked = true } },
    { { low = 99, locked = true, map = 230 } }, { { low = 99, locked = true, difficulty = 2 } },
    { { low = 99, locked = true }, { low = 100, locked = true } },
}
stable = H.insideRunID
for _, locks in ipairs(unsupported) do
    state.locks = locks
    Event(ns, "UPDATE_INSTANCE_INFO")
    assert(H.insideRunID == stable, "missing, secret, foreign or ambiguous lock info must not split")
end
state.combat = true
local requests = state.requests
H:RequestLockInfo(); assert(state.requests == requests)
state.combat = false
Event(ns, "PLAYER_REGEN_ENABLED"); assert(state.requests == requests + 1)
print("PASS: unavailable/ambiguous lockouts are ignored; refresh requests defer during combat")

ResetState(); ns, H = Fixture()
first = Drop(H)
Progress(ns, { { "Boss one", true }, { "Boss two", false } }, 1)
original = H.insideRunID
Move(ns, false); Move(ns, true)
returning = Drop(H)
Progress(ns, { { "Boss one", true }, { "Boss two", false } }, 1)
assert(H.insideRunID == original)
Progress(ns, { { "Boss one", false }, { "Boss two", false } }, 0)
assert(H.insideRunID ~= original and returning.historyEntry.runID == H.insideRunID)
assert(first.historyEntry.runID == original)
stable = H.insideRunID
Progress(ns, { { "Boss one", false }, { "Boss two", false } }, 0)
assert(H.insideRunID == stable, "zero-to-zero progress is not reset evidence")
Event(ns, "BOSS_KILL", 1, "Boss one")
Progress(ns, { { "Boss one", false }, { "Boss two", false } }, 0)
assert(H.insideRunID == stable, "a delayed snapshot during this visit must not undo a fresh kill")
Move(ns, false); Move(ns, true)
Progress(ns, { { "Boss one", false }, { "Boss two", false } }, 0)
assert(H.insideRunID ~= stable, "known kill becoming alive is reset evidence")
print("PASS: complete progress regression splits; equal or all-zero progress does not")

stable = H.insideRunID
Progress(ns, { { "Boss one", true }, { "Boss two", false } }, 1)
Progress(ns, { { "Boss one", false }, { "Boss two", false } }, 1)
assert(H.insideRunID == stable, "inconsistent totals must be ignored")
Progress(ns, { { "Boss one", secret }, { "Boss two", false } }, 0)
assert(H.insideRunID == stable)
state.total, state.completed = 0, 0
Event(ns, "UPDATE_INSTANCE_INFO"); assert(H.insideRunID == stable)
Event(ns, "INSTANCE_LOCK_STOP")
state.bosses, state.total, state.completed = { { "Boss one", false }, { "Boss two", false } }, 2, 0
Event(ns, "UPDATE_INSTANCE_INFO"); assert(H.insideRunID == stable, "ordinary updates are not lock snapshots")
Progress(ns, { { "Boss one", true }, { "Boss two", true } }, 2)
assert(not H:GetActiveRun() and H:GetRun(stable).endReason == "completed")
assert(Drop(H, "Trash after complete lock snapshot").historyEntry.runID == stable)
print("PASS: zero, secret, inconsistent and out-of-context progress cannot imply a reset")

ResetState(); ns, H = Fixture()
Drop(H)
C_EncounterJournal = { GetInstanceForGameMap = function() return 9 end }
function EJ_GetEncounterInfoByIndex(index)
    if index <= 2 then return "Boss " .. index, nil, nil, nil, nil, nil, index end
end
Event(ns, "BOSS_KILL", 2, "Boss 2")
assert(H:GetActiveRun(), "last journal entry alone is not completion")
Event(ns, "BOSS_KILL", 1, "Boss 1")
assert(not H:GetActiveRun() and H:GetRun(H.insideRunID).endReason == "completed")
C_EncounterJournal, EJ_GetEncounterInfoByIndex = nil, nil
local old = Drop(H)
H:StartNewRun()
assert(H.insideRunID ~= old.historyEntry.runID)
local manualID = H.insideRunID
assert(not ns.db.lootRuns[manualID])
assert(Drop(H).historyEntry.runID == manualID)
Move(ns, false); H:StartNewRun(); Move(ns, true)
assert(H.insideRunID ~= manualID)
print("PASS: all known bosses required for catalog completion; manual boundary works inside and outside")

state.locks = { { low = 88, locked = true } }
H:RequestLockInfo(); Event(ns, "UPDATE_INSTANCE_INFO")
Progress(ns, { { "Boss one", true }, { "Boss two", false } }, 1)
Drop(H, "Export evidence")
local rows = assert(ns.DataTransferSpec.export("all"))
local receiver = Fixture()
local plan = assert(receiver.DataTransferSpec.stage(rows))
assert(receiver.DataTransferSpec.apply(plan))
for _, roll in ipairs(receiver.db.rollHistory) do assert(not roll.visitID, "CSV must not import live visit identities") end
local foundEvidence
for _, run in pairs(receiver.db.lootRuns) do
    if run.lockoutKey == "0:88" then
        assert(run.lockProgress["Boss one"] == true and run.lockProgress["Boss two"] == false)
        foundEvidence = true
    end
end
assert(foundEvidence)
print("PASS: CSV preserves run evidence and manual end reason without importing live visit IDs")

RequestRaidInfo, GetNumSavedInstances, GetSavedInstanceInfo = nil, nil, nil
GetInstanceLockTimeRemaining, GetInstanceLockTimeRemainingEncounter = nil, nil
