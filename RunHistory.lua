local _, ns = ...
local H = {}
ns.History = H

local LIMIT_ROLLS = 400
local removedRolls = setmetatable({}, { __mode = "k" })
-- Sessions retain pending runs until delayed roll results arrive.
local pendingRuns = setmetatable({}, { __mode = "v" })
local CHOICE_ORDER = { [1] = 4, [2] = 3, [3] = 2, [0] = 1, [-1] = 0 }
local requestedItems = {}
local requestedQuests = {}
-- This quest has the same title as the Forever instance in the English and Russian client data.
local instanceTitleQuests = { [2970] = 95775 }
local CYR_UPPER = "АБВГДЕ\208\129ЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
local CYR_LOWER = "абвгде\209\145жзийклмнопрстуфхцчшщъыьэюя"
local lower = {}
for i = 1, #CYR_UPPER, 2 do
    lower[CYR_UPPER:sub(i, i + 1)] = CYR_LOWER:sub(i, i + 1)
end

local function Public(value)
    if not ns.IsSecretValue(value) then return value end
end

local function Clock()
    return GetServerTime and GetServerTime() or time()
end

local function Lower(text)
    if type(text) ~= "string" then return "" end
    return text:gsub("[A-Z]", function(letter) return string.char(letter:byte() + 32) end)
        :gsub("[\208\209][\128-\191]", lower)
end

local function Normalize(text)
    return Lower(text):gsub("\209\145", "е"):gsub("[%s%-]+", " "):match("^%s*(.-)%s*$")
end

local function WinnerNameKey(name)
    return Lower(Public(name)):gsub("[%s%-]+", " "):match("^%s*(.-)%s*$")
end

local function ClassToken(value)
    value = Public(value)
    if type(value) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[value] then return value end
end

function H:GetWinnerClass(entry)
    local winner = entry.winner
    if not winner then return end
    local class = ClassToken(winner.class)
    if class then return class end
    local name = WinnerNameKey(winner.name)
    local matched, ambiguous
    for _, player in ipairs(entry.players or {}) do
        if (winner.isSelf and player.isSelf) or (not winner.isSelf and name ~= "" and WinnerNameKey(player.name) == name) then
            if matched then ambiguous = true; break end
            matched = player
        end
    end
    class = not ambiguous and matched and ClassToken(matched.class)
    if class then return class end
    if winner.isSelf and self.character and type(UnitClass) == "function" then
        local run = entry.runID and ns.db.lootRuns[entry.runID]
        if (entry.character or (run and run.character)) == self.character then
            return ClassToken(select(2, UnitClass("player")))
        end
    end
end

function H:Matches(value, query)
    return Normalize(value):find(query, 1, true) ~= nil
end

function H:GetItemName(entry)
    local link = Public(entry.link)
    local id = type(link) == "string" and tonumber(link:match("|Hitem:(%d+)"))
    if id and type(ns.GetItemInfo) == "function" then
        local ok, name = pcall(ns.GetItemInfo, link)
        name = ok and Public(name)
        if type(name) == "string" and name ~= "" then return name end
        if not requestedItems[id] and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
            requestedItems[id] = true
            pcall(C_Item.RequestLoadItemDataByID, id)
        end
    end
    return entry.name or (entry.link and entry.link:match("%[(.-)%]")) or ns.L.ITEM_FALLBACK
end

local function JournalInstance(run)
    if not (run and run.mapID and C_EncounterJournal
        and type(C_EncounterJournal.GetInstanceForGameMap) == "function") then return end
    local ok, id = pcall(C_EncounterJournal.GetInstanceForGameMap, run.mapID)
    id = ok and Public(id)
    if type(id) == "number" and id > 0 then return id end
end

local function ObservedInstanceName(run)
    local locale = Public(GetLocale())
    local names = ns.db.lootInstanceNames
    local byLocale = type(names) == "table" and names[locale]
    local name = type(byLocale) == "table" and Public(byLocale[run.mapID])
    if type(name) == "string" and name ~= "" then return name end
end

local function QuestInstanceName(run)
    local id = instanceTitleQuests[run.mapID]
    if not (id and C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function") then return end
    local name = Public(C_QuestLog.GetTitleForQuestID(id))
    if type(name) == "string" and name ~= "" then return name end
    if not requestedQuests[id] and type(C_QuestLog.RequestLoadQuestByID) == "function" then
        requestedQuests[id] = true
        C_QuestLog.RequestLoadQuestByID(id)
    end
end

local function JournalSourceID(run, source)
    local instance = JournalInstance(run)
    if not instance or type(source) ~= "string" or type(EJ_GetEncounterInfoByIndex) ~= "function" then return end
    local match
    for index = 1, 100 do
        local ok, name, _, id = pcall(EJ_GetEncounterInfoByIndex, index, instance)
        name, id = Public(name), Public(id)
        if not ok or not name then break end
        if name == source and type(id) == "number" and id > 0 then
            if match then return end
            match = id
        end
    end
    return match
end

function H:GetSourceName(entry)
    if entry.sourceJournalID and type(EJ_GetEncounterInfo) == "function" then
        local ok, name = pcall(EJ_GetEncounterInfo, entry.sourceJournalID)
        name = ok and Public(name)
        if type(name) == "string" and name ~= "" then return name end
    end
    if entry.source == "Разное" or entry.source == "Miscellaneous" then
        local locale = GetLocale()
        if locale == "ruRU" then return "Разное" end
        if locale == "enUS" or locale == "enGB" then return "Miscellaneous" end
    end
    return entry.source
end

function H:GetActiveRun()
    local id = self.character and ns.db.activeLootRuns[self.character]
    return self.activeRun or (id and ns.db.lootRuns[id])
end

function H:GetRun(id)
    return id and (ns.db.lootRuns[id] or pendingRuns[id])
end

local function Instance()
    if type(GetInstanceInfo) ~= "function" then return end
    local name, kind, difficulty, _, _, _, _, mapID = GetInstanceInfo()
    name, kind, difficulty, mapID = Public(name), Public(kind), Public(difficulty), Public(mapID)
    if (kind == "party" or kind == "raid") and type(name) == "string" and type(difficulty) == "number"
        and type(mapID) == "number" and mapID > 0 then
        return name, kind, difficulty, mapID
    end
    return nil, nil, nil, nil, kind == "none" or kind == "pvp" or kind == "arena" or kind == "scenario"
end

function H:UpdateView()
    if self.frame and self.frame:IsShown() then self:Refresh() end
end

function H:TrimRuns()
    local keep = {}
    for _, entry in ipairs(ns.db.rollHistory) do
        if entry.runID then keep[entry.runID] = true end
    end
    for id, run in pairs(ns.db.lootRuns) do
        if not keep[id] then
            pendingRuns[id] = run
            ns.db.lootRuns[id] = nil
        end
    end
    for _, links in ipairs({ ns.db.activeLootRuns, ns.db.lootRunPresence }) do
        for character, id in pairs(links) do
            if not keep[id] then links[character] = nil end
        end
    end
    for character, visit in pairs(ns.db.lootRunVisits) do
        if not keep[visit.runID] then ns.db.lootRunVisits[character] = nil end
    end
end

function H:SaveRun(run)
    ns.db.lootRuns[run.id] = run
    if self:GetActiveRun() == run then ns.db.activeLootRuns[self.character] = run.id end
    if self.presenceRun == run then ns.db.lootRunPresence[self.character] = run.id end
    self:SaveVisit()
end

function H:SaveVisit()
    local visit = self.visit
    if visit and ns.db.lootRuns[visit.run.id] then
        ns.db.lootRunVisits[self.character] = { id = visit.id, runID = visit.run.id, startedAt = visit.startedAt,
            baselineDead = visit.baselineDead, baselineLocale = visit.baselineLocale, baselineLockoutKey = visit.baselineLockoutKey,
            killedEncounters = visit.killedEncounters, killedBossNames = visit.killedBossNames,
            previousKills = visit.previousKills, previousNames = visit.previousNames }
    end
end

function H:StartVisit(run, reload)
    local saved = reload and ns.db.lootRunVisits[self.character]
    if saved and saved.runID == run.id then
        self.visit = { id = saved.id, startedAt = saved.startedAt, run = run,
            baselineDead = saved.baselineDead, baselineLocale = saved.baselineLocale, baselineLockoutKey = saved.baselineLockoutKey,
            killedEncounters = saved.killedEncounters, killedBossNames = saved.killedBossNames,
            previousKills = saved.previousKills, previousNames = saved.previousNames }
    else
        ns.db.nextLootVisitID = ns.db.nextLootVisitID + 1
        local dead = {}
        for name, killed in pairs(run.lockProgress or {}) do if killed then dead[name] = true end end
        for name, killed in pairs(run.killedBossNames or {}) do if killed then dead[name] = true end end
        self.visit = { id = ns.db.nextLootVisitID, startedAt = Clock(), run = run,
            baselineDead = dead, baselineLocale = run.progressLocale, baselineLockoutKey = run.lockoutKey }
    end
    self.lockRequestVisitID, self.requestLockInfoAfterCombat = nil, nil
    self:SaveVisit()
end

function H:Archive(reason, endedAt)
    local run = self:GetActiveRun()
    if not run then return end
    run.endedAt = math.max(run.startedAt, endedAt or Clock())
    run.endReason = reason
    self.activeRun = nil
    ns.db.activeLootRuns[self.character] = nil
    if reason ~= "completed" then
        self.presenceRun = nil
        ns.db.lootRunPresence[self.character] = nil
    end
    -- Keep the in-instance association for rolls delivered after the finish event.
    self:TrimRuns()
    self:UpdateView()
end

function H:BeginRun(name, kind, difficulty, mapID, visit)
    local id = ns.db.nextLootRunID + 1
    ns.db.nextLootRunID = id
    local run = { id = id, name = name, kind = kind, difficulty = difficulty, mapID = mapID,
        character = self.character, startedAt = visit and visit.startedAt or Clock() }
    pendingRuns[id] = run
    self.activeRun, self.presenceRun = run, run
    ns.db.activeLootRuns[self.character] = nil
    ns.db.lootRunPresence[self.character] = nil
    self.insideRunID = id
    if visit then
        visit.run, self.visit = run, visit
        visit.baselineDead, visit.baselineLocale, visit.baselineLockoutKey = nil, nil, nil
    else
        self:StartVisit(run)
    end
    self:TrimRuns()
    return run
end

function H:CloseRun(reason)
    if not self.character then return end
    self:Archive(reason)
    self.insideRunID, self.presenceRun, self.visit = nil, nil, nil
    self.lockPrompt = nil
    self.lockRequestVisitID, self.requestLockInfoAfterCombat = nil, nil
    ns.db.lootRunPresence[self.character] = nil
    ns.db.lootRunVisits[self.character] = nil
    self:UpdateView()
end

function H:StartNewRun()
    self:ObserveInstance()
    if not self.character then return false end
    self:CloseRun("manual")
    self:ObserveInstance()
    return true
end

function H:SplitVisit(reason)
    local visit = self.visit
    if not visit then return end
    local old = visit.run
    self:Archive(reason, visit.startedAt)
    local run = self:BeginRun(old.name, old.kind, old.difficulty, old.mapID, visit)
    for id, previous in pairs(visit.previousKills or {}) do old.killedEncounters[id] = previous or nil end
    for name, previous in pairs(visit.previousNames or {}) do old.killedBossNames[name] = previous or nil end
    run.killedEncounters, run.killedBossNames = visit.killedEncounters, visit.killedBossNames
    if run.killedBossNames then run.progressLocale = GetLocale() end
    visit.previousKills, visit.previousNames = nil, nil
    for _, entry in ipairs(ns.db.rollHistory) do
        if entry.character == self.character and entry.visitID == visit.id and entry.runID == old.id then
            entry.runID = run.id
            self:SaveRun(run)
        end
    end
    self:TrimRuns()
    self:SaveVisit()
    self:UpdateView()
    return run
end

function H:ObserveInstance(forceNew, reload)
    self.character = self.character or (type(UnitGUID) == "function" and Public(UnitGUID("player")))
    if type(self.character) ~= "string" then self.character = nil; return end

    local name, kind, difficulty, mapID, outside = Instance()
    local locale = Public(GetLocale())
    if name and type(locale) == "string" and locale ~= "" then
        local names = ns.db.lootInstanceNames
        if type(names) ~= "table" then names = {}; ns.db.lootInstanceNames = names end
        if type(names[locale]) ~= "table" then names[locale] = {} end
        names[locale][mapID] = name
    end
    local previousInside = self.insideRunID
    if not name then
        if forceNew then self:CloseRun("reset") end
        if not outside then return end
        local run = self:GetRun(previousInside) or self.presenceRun or self:GetRun(ns.db.lootRunPresence[self.character])
        if run and run.endReason == "completed" then
            self.presenceRun = nil
            ns.db.lootRunPresence[self.character] = nil
        end
        self.insideRunID = nil
        self.visit, self.lockPrompt = nil, nil
        ns.db.lootRunVisits[self.character] = nil
        if previousInside then self:UpdateView() end
        return
    end

    local savedID = ns.db.lootRunPresence[self.character]
    local run = self:GetRun(previousInside) or self.presenceRun or self:GetRun(savedID) or self:GetActiveRun()
    local sameMap = run and run.mapID == mapID and run.kind == kind and run.difficulty == difficulty
    local savedVisit = ns.db.lootRunVisits[self.character]
    local wasInside = sameMap and savedVisit and savedVisit.runID == run.id
    local finishedVisit = sameMap and run.endReason == "completed" and not previousInside and not reload and not wasInside
    if forceNew or not sameMap or finishedVisit then
        self:Archive(forceNew and "reset" or "left")
        self:BeginRun(name, kind, difficulty, mapID)
    else
        self.insideRunID = run.id
        self.presenceRun = run
        if self:GetActiveRun() == run then self.activeRun = run end
        if ns.db.lootRuns[run.id] then ns.db.lootRunPresence[self.character] = run.id end
        if not self.visit then self:StartVisit(run, reload) end
    end
    if forceNew or previousInside ~= self.insideRunID then self:UpdateView() end
end

function H:GetRollRunID()
    self:ObserveInstance()
    return self.insideRunID or false, self:GetRun(self.insideRunID), self.visit
end

function H:Init()
    for _, key in ipairs({ "lootRuns", "activeLootRuns", "lootRunPresence", "lootAttemptCarry", "lootRunVisits" }) do
        if type(ns.db[key]) ~= "table" then ns.db[key] = {} end
    end
    if type(ns.db.nextLootRunID) ~= "number" then
        ns.db.nextLootRunID = 0
        for id in pairs(ns.db.lootRuns) do
            if type(id) == "number" then ns.db.nextLootRunID = math.max(ns.db.nextLootRunID, id) end
        end
    end
    if type(ns.db.nextLootVisitID) ~= "number" then
        ns.db.nextLootVisitID = 0
        for _, entry in ipairs(ns.db.rollHistory) do
            if type(entry.visitID) == "number" then ns.db.nextLootVisitID = math.max(ns.db.nextLootVisitID, entry.visitID) end
        end
    end
    for character, visit in pairs(ns.db.lootRunVisits) do
        if type(visit) ~= "table" or type(visit.id) ~= "number" or type(visit.startedAt) ~= "number" then
            ns.db.lootRunVisits[character] = nil
        else
            ns.db.nextLootVisitID = math.max(ns.db.nextLootVisitID, visit.id)
        end
    end
    self:TrimRuns()
    ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, id, success)
        if requestedItems[id] == true and success and C_Timer and type(C_Timer.After) == "function" then
            requestedItems[id] = "loaded"
            C_Timer.After(0, function() self:UpdateView() end)
        end
    end)
    ns:RegisterEvent("QUEST_DATA_LOAD_RESULT", function(_, id, success)
        if requestedQuests[id] == true and success and C_Timer and type(C_Timer.After) == "function" then
            requestedQuests[id] = "loaded"
            C_Timer.After(0, function() self:UpdateView() end)
        end
    end)
    ns:RegisterEvent("PLAYER_ENTERING_WORLD", function(_, _, reload)
        self.lockPrompt = nil
        self:ObserveInstance(false, Public(reload) == true)
        self:RequestLockInfo()
    end)
    ns:RegisterEvent("GROUP_LEFT", function()
        if self.character and type(IsInGroup) == "function" and Public(IsInGroup()) == false then
            self:CloseRun("left")
        end
    end)
    ns:RegisterEvent("CHALLENGE_MODE_START", function()
        self:ObserveInstance(true)
    end)
    ns:RegisterEvent("CHALLENGE_MODE_RESET", function()
        self:CloseRun("reset")
    end)
    for _, event in ipairs({ "LFG_COMPLETION_REWARD", "CHALLENGE_MODE_COMPLETED" }) do
        ns:RegisterEvent(event, function()
            local run = self:GetActiveRun()
            if run and run.id == self.insideRunID then self:Archive("completed") end
        end)
    end
    self:InitRunEvidence()
    ns:RegisterEvent("CHAT_MSG_SYSTEM", function(_, message)
        self:ObserveInstance()
        if not self.character or self.insideRunID or type(Public(message)) ~= "string" then return end
        local run = self.presenceRun or self:GetRun(ns.db.lootRunPresence[self.character]) or self:GetActiveRun()
        local format = INSTANCE_RESET_SUCCESS
        if run and type(format) == "string" then
            format = format:gsub("%%1%$s", "%%s")
            local currentName = ObservedInstanceName(run) or run.name
            if type(currentName) == "string" and format:find("%s", 1, true) and message == format:format(currentName) then
                self:CloseRun("reset")
            end
        end
    end)
end

local function WonRoll(entry)
    return not entry.allPassed and entry.winner and entry.winner.isSelf == true
end

local function CarryAttempt(entry)
    local character, itemID = entry.character, entry.attemptItemID
    if not character or not itemID then return end
    local allCharacters = ns.db.lootAttemptCarry
    local counts = allCharacters[character]
    if WonRoll(entry) then
        if not counts then return end
        counts[itemID] = nil
        if not next(counts) then allCharacters[character] = nil end
        return
    end
    if not counts then
        counts = {}
        allCharacters[character] = counts
    end
    counts[itemID] = (counts[itemID] or 0) + 1
end

local function FindDuplicate(history, record, character, signature, now)
    local duplicate, recordIndex
    for index, saved in ipairs(history) do
        if saved == record then
            recordIndex = index
        elseif saved.character == character and saved.dropSignature == signature and type(saved.time) == "number"
            and math.abs(now - saved.time) <= 300 then
            duplicate = saved
        end
    end
    if duplicate and recordIndex then table.remove(history, recordIndex) end
    return duplicate
end

function H:Record(session)
    if session.isSimulated or (session.historyEntry and removedRolls[session.historyEntry]) then return end
    local history = ns.db.rollHistory
    local record = session.historyEntry
    local signature = session.historyDropSignature
    if signature and not session.historySignatureChecked and self.character then
        local duplicate = FindDuplicate(history, record, self.character, signature, Clock())
        if duplicate then
            record = duplicate
            session.historyEntry = duplicate
            session.historyRecovered = true
        end
        session.historySignatureChecked = true
    end
    if not record then
        local visit = session.historyVisit
        local runID = visit and visit.run.id or session.historyRunID
        session.historyRunID = runID
        record = {
            time = session.historyStartedAt or Clock(),
            runID = runID or nil,
            outside = runID == false or nil,
            character = self.character,
            visitID = visit and visit.id,
        }
        session.historyEntry = record
        table.insert(history, 1, record)
        local run = (visit and visit.run) or self:GetRun(runID) or session.historyRun
        if run and run.id == runID then
            self:SaveRun(run)
        end
        if #history > LIMIT_ROLLS then
            CarryAttempt(table.remove(history))
            self:TrimRuns()
        end
    end
    record.dropSignature = signature or record.dropSignature
    record.name = session.itemName or record.name
    record.link = session.itemLink or record.link
    record.icon = session.itemTexture or record.icon
    record.quality = session.itemQuality or record.quality
    if session.historySource and session.historySource ~= record.source then
        record.source, record.sourceJournalID = session.historySource, nil
    end
    if record.source and not record.sourceJournalID then
        record.sourceJournalID = JournalSourceID(self:GetRun(record.runID) or session.historyRun, record.source)
    end
    if session.winner then
        local previous, winner = record.winner, session.winner
        if not ClassToken(winner.class) and previous and WinnerNameKey(winner.name) == WinnerNameKey(previous.name) then
            winner.class = ClassToken(previous.class)
        end
        record.winner = winner
    end
    record.allPassed = not record.winner and (session.allPassed or record.allPassed)
    record.choice, record.score = session.myChoice or record.choice, session.myScore or record.score
    if record.character and not record.attemptItemID and type(record.link) == "string" then
        record.attemptItemID = tonumber(record.link:match("|Hitem:(%d+)"))
    end
    local players = {}
    local recovered = {}
    if session.historyRecovered then
        for _, player in ipairs(record.players or {}) do recovered[player.name] = player end
    end
    for _, player in pairs(session.players) do
        local saved = recovered[player.name]
        recovered[player.name] = nil
        local choice, detail = player.rollType, player.rollDetail
        if saved and player.rollType == ns.DataTracker.ROLL_TYPE_PENDING then
            choice, detail = saved.choice, saved.rollDetail
        end
        players[#players + 1] = { name = player.name, choice = choice, rollDetail = detail,
            score = player.rollScore or (saved and saved.score), class = player.class or (saved and saved.class),
            isSelf = player.isSelf or (saved and saved.isSelf) }
    end
    for _, player in pairs(recovered) do players[#players + 1] = player end
    table.sort(players, function(a, b)
        if a.choice ~= b.choice then return (CHOICE_ORDER[a.choice] or -1) > (CHOICE_ORDER[b.choice] or -1) end
        if a.score ~= b.score then return (a.score or -1) > (b.score or -1) end
        return (a.name or "") < (b.name or "")
    end)
    record.players = players
    if record.winner then record.winner.class = self:GetWinnerClass(record) end
    self:UpdateView()
end

function H:RemoveRolls(matches)
    local history = ns.db.rollHistory
    for index = #history, 1, -1 do
        if matches(history[index]) then removedRolls[table.remove(history, index)] = true end
    end
    self:TrimRuns()
end

function H:GetPersonalAttempts()
    local attempts, counts = {}, {}
    if not self.character then return attempts end
    local carry = ns.db.lootAttemptCarry[self.character]
    local history = ns.db.rollHistory
    for index = #history, 1, -1 do
        local entry = history[index]
        local itemID = entry.attemptItemID
        if entry.character == self.character and itemID then
            local count = (counts[itemID] or (carry and carry[itemID]) or 0) + 1
            if WonRoll(entry) then
                attempts[entry] = count
                counts[itemID] = 0
            else
                counts[itemID] = count
            end
        end
    end
    return attempts
end

local function MatchesPlayer(history, entry, query)
    if query == "" then return false end
    for _, player in ipairs(entry.players or {}) do
        if history:Matches(player.name, query) then return true end
    end
    return entry.winner and history:Matches(entry.winner.name, query) or false
end

local function GetRunName(entry, run)
    if run then
        local observed = ObservedInstanceName(run)
        if observed then return observed end
        local id = JournalInstance(run)
        if id and type(EJ_GetInstanceInfo) == "function" then
            local ok, name = pcall(EJ_GetInstanceInfo, id)
            name = ok and Public(name)
            if type(name) == "string" and name ~= "" then return name end
        end
        return QuestInstanceName(run) or run.name
    end
    return entry.outside and ns.L.HISTORY_OUTSIDE or ns.L.HISTORY_LEGACY
end

function H:FindPersonalLoot(text)
    local query = Normalize(text)
    local results = {}
    if not self.character then return results, query end

    local characterName = ns.RosterInspector:GetUnitNames("player")
    for _, entry in ipairs(ns.db.rollHistory) do
        local winner = entry.winner
        if WonRoll(entry) then
            local run = entry.runID and ns.db.lootRuns[entry.runID]
            local character = entry.character or (run and run.character)
            -- Earlier entries outside a recorded run can only be attributed by the recorded winner's name.
            local mine = character == self.character or (not character and characterName and winner.name
                and Normalize(ns.RosterInspector:GetShortName(winner.name)) == Normalize(characterName))
            if mine and (query == "" or self:Matches(self:GetItemName(entry), query)
                or self:Matches(GetRunName(entry, run), query) or MatchesPlayer(self, entry, query)) then
                results[#results + 1] = entry
            end
        end
    end
    return results, query
end

function H:GetRunName(entry)
    return GetRunName(entry, entry.runID and ns.db.lootRuns[entry.runID])
end

function H:FindRuns(text)
    local query = Normalize(text)
    local groups, results = {}, {}
    local active = self:GetActiveRun()
    local function Group(key, run)
        if not groups[key] then
            groups[key] = { key = key, run = run, entries = {}, active = run and run == active or false }
        end
        return groups[key]
    end

    for _, entry in ipairs(ns.db.rollHistory) do
        local run = entry.runID and ns.db.lootRuns[entry.runID]
        local key = run and entry.runID or (entry.outside and "outside" or "legacy")
        local group = Group(key, run)
        group.name = GetRunName(entry, run)
        local playerMatch = MatchesPlayer(self, entry, query)
        if query == "" or playerMatch or self:Matches(group.name, query) or self:Matches(self:GetItemName(entry), query) then
            group.entries[#group.entries + 1] = entry
            if playerMatch and not group.playerMatch then group.playerMatch = entry end
        end
    end

    for _, group in pairs(groups) do
        group.name = group.name or group.run.name
        if #group.entries > 0 then
            results[#results + 1] = group
        end
    end
    table.sort(results, function(a, b)
        if a.key == b.key then return false end
        if a.active ~= b.active then return a.active end
        if a.run and b.run then return a.run.id > b.run.id end
        if not a.run and not b.run then return a.key == "outside" end
        return a.run ~= nil
    end)
    return results, query
end
