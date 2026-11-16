local _, ns = ...
local H = {}
ns.History = H

local LIMIT_ROLLS, LIMIT_EMPTY_RUNS = 400, 40
local removedRolls = setmetatable({}, { __mode = "k" })
local CHOICE_ORDER = { [1] = 4, [2] = 3, [3] = 2, [0] = 1, [-1] = 0 }
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
    return entry.name or (entry.link and entry.link:match("%[(.-)%]")) or ns.L.ITEM_FALLBACK
end

function H:GetActiveRun()
    local id = self.character and ns.db.activeLootRuns[self.character]
    return id and ns.db.lootRuns[id]
end

local function Instance()
    if type(GetInstanceInfo) ~= "function" then return end
    local name, kind, difficulty, _, _, _, _, mapID = GetInstanceInfo()
    name, kind, difficulty, mapID = Public(name), Public(kind), Public(difficulty), Public(mapID)
    if (kind == "party" or kind == "raid") and type(name) == "string" and type(mapID) == "number" and mapID > 0 then
        return name, kind, difficulty, mapID
    end
end

local function TargetInstance()
    if type(UnitGUID) ~= "function" then return end
    for _, unit in ipairs({ "boss1", "target" }) do
        local guid = Public(UnitGUID(unit))
        if type(guid) == "string" then
            local copy, zone = guid:match("^Creature%-%d+%-(%d+%-%d+%-(%d+))%-")
            if copy and tonumber(zone) > 0 then return copy end
        end
    end
end

function H:UpdateView()
    if self.frame and self.frame:IsShown() then self:Refresh() end
end

function H:TrimRuns()
    local keep = {}
    for _, entry in ipairs(ns.db.rollHistory) do
        if entry.runID then keep[entry.runID] = true end
    end
    for _, id in pairs(ns.db.activeLootRuns) do keep[id] = true end
    for _, id in pairs(ns.db.lootRunPresence) do keep[id] = true end
    if self.insideRunID then keep[self.insideRunID] = true end
    local empty = {}
    for id, run in pairs(ns.db.lootRuns) do
        if not keep[id] then empty[#empty + 1] = run end
    end
    if #empty <= LIMIT_EMPTY_RUNS then return end
    table.sort(empty, function(a, b) return a.id > b.id end)
    for i = LIMIT_EMPTY_RUNS + 1, #empty do ns.db.lootRuns[empty[i].id] = nil end
end

function H:Archive(reason)
    local run = self:GetActiveRun()
    if not run then return end
    run.endedAt = Clock()
    run.endReason = reason
    ns.db.activeLootRuns[self.character] = nil
    if reason ~= "completed" then ns.db.lootRunPresence[self.character] = nil end
    -- Keep the in-instance association for rolls delivered after the finish event.
    if self.insideRunID ~= run.id then self.checkInstanceCopy = false end
    self:TrimRuns()
    self:UpdateView()
end

function H:BeginRun(name, kind, difficulty, mapID, copy)
    local id = ns.db.nextLootRunID + 1
    ns.db.nextLootRunID = id
    local run = { id = id, name = name, kind = kind, difficulty = difficulty, mapID = mapID,
        character = self.character, startedAt = Clock(), instanceCopy = copy }
    ns.db.lootRuns[id] = run
    ns.db.activeLootRuns[self.character] = id
    ns.db.lootRunPresence[self.character] = id
    self.insideRunID = id
    self.checkInstanceCopy = false
    self:TrimRuns()
    return run
end

function H:ObserveInstance(forceNew)
    self.character = self.character or (type(UnitGUID) == "function" and Public(UnitGUID("player")))
    if type(self.character) ~= "string" then self.character = nil; return end

    local name, kind, difficulty, mapID = Instance()
    local previousInside = self.insideRunID
    if not name then
        self.insideRunID = nil
        self.checkInstanceCopy = false
        if previousInside then self:UpdateView() end
        return
    end

    local savedID = ns.db.lootRunPresence[self.character]
    local run = ns.db.lootRuns[previousInside or savedID] or self:GetActiveRun()
    local sameMap = run and run.mapID == mapID and run.kind == kind and run.difficulty == difficulty
    if forceNew or not sameMap then
        self:Archive(forceNew and "reset" or "left")
        self:BeginRun(name, kind, difficulty, mapID)
    else
        self.insideRunID = run.id
        ns.db.lootRunPresence[self.character] = run.id
        if not previousInside and run.instanceCopy then self.checkInstanceCopy = true end
    end
    if forceNew or previousInside ~= self.insideRunID then self:UpdateView() end
end

function H:ObserveTarget()
    local run = ns.db.lootRuns[self.insideRunID]
    if not run or (run.instanceCopy and not self.checkInstanceCopy) then return end
    local copy = TargetInstance()
    if not copy then return end
    self.checkInstanceCopy = false
    if not run.instanceCopy then
        run.instanceCopy = copy
    elseif copy ~= run.instanceCopy then
        self:Archive("left")
        self:BeginRun(run.name, run.kind, run.difficulty, run.mapID, copy)
        self:UpdateView()
    end
end

function H:GetRollRunID()
    self:ObserveInstance()
    self:ObserveTarget()
    return self.insideRunID or false
end

function H:CheckEncounterCompletion()
    local run = self:GetActiveRun()
    if not run or run.id ~= self.insideRunID or self.lastSuccessfulRun ~= run.id
        or type(GetInstanceLockTimeRemaining) ~= "function" then return end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and Public(C_ChallengeMode.IsChallengeModeActive()) == true then return end
    local _, _, total, completed = GetInstanceLockTimeRemaining()
    total, completed = Public(total), Public(completed)
    if type(total) == "number" and total > 0 and completed == total then self:Archive("completed") end
end

function H:CheckLastBoss(encounterID)
    local run = self:GetActiveRun()
    if not run or run.id ~= self.insideRunID or type(encounterID) ~= "number" then return end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and Public(C_ChallengeMode.IsChallengeModeActive()) == true then return end
    if not (C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap and EJ_GetEncounterInfoByIndex) then return end
    local journalID = Public(C_EncounterJournal.GetInstanceForGameMap(run.mapID))
    if type(journalID) ~= "number" or journalID <= 0 then return end
    local finalID
    for index = 1, 40 do
        local name, _, _, _, _, _, id = EJ_GetEncounterInfoByIndex(index, journalID)
        if type(Public(name)) ~= "string" then break end
        finalID = Public(id)
    end
    if finalID == encounterID then self:Archive("completed") end
end

function H:Init()
    for _, key in ipairs({ "lootRuns", "activeLootRuns", "lootRunPresence", "lootAttemptCarry" }) do
        if type(ns.db[key]) ~= "table" then ns.db[key] = {} end
    end
    if type(ns.db.nextLootRunID) ~= "number" then
        ns.db.nextLootRunID = 0
        for id in pairs(ns.db.lootRuns) do
            if type(id) == "number" then ns.db.nextLootRunID = math.max(ns.db.nextLootRunID, id) end
        end
    end
    ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        self:ObserveInstance()
        self:ObserveTarget()
    end)
    ns:RegisterEvent("PLAYER_TARGET_CHANGED", function() self:ObserveTarget() end)
    ns:RegisterEvent("GROUP_LEFT", function()
        if self.character and type(IsInGroup) == "function" and Public(IsInGroup()) == false then
            ns.db.lootRunPresence[self.character] = nil
            self:Archive("left")
        end
    end)
    ns:RegisterEvent("CHALLENGE_MODE_START", function()
        if self:GetActiveRun() then return end
        self:ObserveInstance(true)
    end)
    ns:RegisterEvent("CHALLENGE_MODE_RESET", function()
        if self.insideRunID then
            self:Archive("reset")
            self.insideRunID = nil
            ns.db.lootRunPresence[self.character] = nil
        end
    end)
    for _, event in ipairs({ "LFG_COMPLETION_REWARD", "CHALLENGE_MODE_COMPLETED" }) do
        ns:RegisterEvent(event, function()
            local run = self:GetActiveRun()
            if run and run.id == self.insideRunID then self:Archive("completed") end
        end)
    end
    ns:RegisterEvent("ENCOUNTER_END", function(_, encounterID, _, _, _, success)
        if Public(success) == 1 then
            self.lastSuccessfulRun = self.insideRunID
            self:CheckEncounterCompletion()
            self:CheckLastBoss(Public(encounterID))
        end
    end)
    ns:RegisterEvent("UPDATE_INSTANCE_INFO", function() self:CheckEncounterCompletion() end)
    ns:RegisterEvent("CHAT_MSG_SYSTEM", function(_, message)
        if not self.character or self.insideRunID or type(Public(message)) ~= "string" then return end
        local run = ns.db.lootRuns[ns.db.lootRunPresence[self.character]]
        local format = INSTANCE_RESET_SUCCESS
        if run and type(format) == "string" then
            format = format:gsub("%%1%$s", "%%s")
            if format:find("%s", 1, true) and message == format:format(run.name) then
                ns.db.lootRunPresence[self.character] = nil
                self:Archive("reset")
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
        local runID = session.historyRunID
        record = {
            time = session.historyStartedAt or Clock(),
            runID = runID or nil,
            outside = runID == false or nil,
            character = self.character,
        }
        session.historyEntry = record
        table.insert(history, 1, record)
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
    record.source = session.historySource or record.source
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
    return run and run.name or (entry.outside and ns.L.HISTORY_OUTSIDE or ns.L.HISTORY_LEGACY)
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

    for id, run in pairs(ns.db.lootRuns) do Group(id, run) end
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
        if #group.entries > 0 or (group.run and self:Matches(group.name, query)) then
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
