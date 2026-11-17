local ns, H = FreshHistory()
local requested, loaded, refreshes = {}, false, 0
local deferred
C_Timer = { After = function(_, callback) deferred = callback end }
C_Item = { RequestLoadItemDataByID = function(id) requested[id] = (requested[id] or 0) + 1 end }
ns.GetItemInfo = function(link)
    assert(link == "|Hitem:123:0|h[Старое имя]|h")
    if loaded then return "Current item" end
end
local entry = { name = "Старое имя", link = "|Hitem:123:0|h[Старое имя]|h" }
assert(H:GetItemName(entry) == "Старое имя")
assert(H:GetItemName(entry) == "Старое имя" and requested[123] == 1)
H.frame = { IsShown = function() return true end }
H.Refresh = function() refreshes = refreshes + 1 end
ns.events.GET_ITEM_INFO_RECEIVED(nil, 123, true)
assert(deferred and refreshes == 0)
loaded = true; deferred()
assert(refreshes == 1 and H:GetItemName(entry) == "Current item")
assert(entry.name == "Старое имя")

C_EncounterJournal = { GetInstanceForGameMap = function(id) if id == 109 then return 9 end end }
EJ_GetInstanceInfo = function(id) assert(id == 9); return "Sunken Temple" end
EJ_GetEncounterInfoByIndex = function(index, id)
    assert(id == 9)
    if index == 1 then return "Босс", nil, 42 end
end
EJ_GetEncounterInfo = function(id) assert(id == 42); return "Boss" end
local run = H:GetActiveRun()
run.name = "Затонувший город"
ns.db.lootInstanceNames = {}
local session = { historyRunID = run.id, historyRun = run, historyVisit = H.visit,
    itemName = "Старое имя", itemLink = entry.link, historySource = "Босс", players = {}, allPassed = true }
H:Record(session)
local saved = session.historyEntry
assert(saved.sourceJournalID == 42 and H:GetSourceName(saved) == "Boss")
assert(H:GetRunName(saved) == "Sunken Temple")
assert(#H:FindRuns("sunken") == 1 and #H:FindRuns("current item") == 1)
assert(H:GetSourceName({ source = "Разное" }) == "Miscellaneous")
assert(H:GetSourceName({ source = "Неизвестный босс" }) == "Неизвестный босс")
local rows = assert(ns.DataTransferSpec.export("all"))
local imported = FreshHistory()
local plan = assert(imported.DataTransferSpec.stage(rows))
assert(imported.DataTransferSpec.apply(plan))
assert(imported.db.rollHistory[1].sourceJournalID == 42)
EJ_GetInstanceInfo, EJ_GetEncounterInfo, EJ_GetEncounterInfoByIndex, C_EncounterJournal, C_Item, C_Timer = nil, nil, nil, nil, nil, nil
assert(H:GetRunName(saved) == "Затонувший город" and H:GetSourceName(saved) == "Босс")
print("PASS: localized history names, deferred item loading, fallbacks, search and CSV")

local lang, inside, currentName = "ruRU", true, "Затонувший город"
function GetLocale() return lang end
function GetInstanceInfo() return currentName, inside and "party" or "none", 1, nil, nil, nil, nil, 2970 end
local localNS, localH = FreshHistory()
local runID, instance, visit = localH:GetRollRunID()
local roll = { historyRunID = runID, historyRun = instance, historyVisit = visit,
    itemName = "Item", players = {}, allPassed = true }
localH:Record(roll)
inside = false; localNS.events.PLAYER_ENTERING_WORLD()
lang, currentName = "frFR", "La cité submergée"
inside = true; localNS.events.PLAYER_ENTERING_WORLD()
assert(localH:GetRunName(roll.historyEntry) == currentName)
inside = false; localNS.events.PLAYER_ENTERING_WORLD()
INSTANCE_RESET_SUCCESS = "%1$s a été réinitialisée."
localNS.events.CHAT_MSG_SYSTEM(nil, "Autre donjon a été réinitialisée.")
assert(instance.endReason == nil)
localNS.events.CHAT_MSG_SYSTEM(nil, "La cité submergée a été réinitialisée.")
assert(instance.endReason == "reset")
assert(instance.name == "Затонувший город")
local reloadNS, reloadH = FreshHistory(localNS.db)
assert(reloadH:GetRunName(roll.historyEntry) == currentName)

localNS.db.lootInstanceNames = {}
local pending, questTitle
C_Timer = { After = function(_, callback) pending = callback end }
C_QuestLog = {
    GetTitleForQuestID = function(id) assert(id == 95775); return questTitle end,
    RequestLoadQuestByID = function(id) assert(id == 95775) end,
}
assert(localH:GetRunName(roll.historyEntry) == "Затонувший город")
questTitle = "La cité submergée"
localH.frame = { IsShown = function() return true end }
localH.Refresh = function() end
localNS.events.QUEST_DATA_LOAD_RESULT(nil, 95775, true)
assert(pending); pending()
assert(localH:GetRunName(roll.historyEntry) == questTitle)
C_Timer, C_QuestLog = nil, nil
print("PASS: locale-specific instance names, French reset, persisted observations and quest title fallback")
