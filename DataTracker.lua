local addonName, ns = ...
local L = ns.L

local DataTracker = {}
ns.DataTracker = DataTracker

-- Standard WoW Roll Types
DataTracker.ROLL_TYPE_PASS = 0
DataTracker.ROLL_TYPE_NEED = 1
DataTracker.ROLL_TYPE_GREED = 2
DataTracker.ROLL_TYPE_DISENCHANT = 3
DataTracker.ROLL_TYPE_PENDING = -1
DataTracker.ROLL_ICONS = {
    [DataTracker.ROLL_TYPE_NEED] = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    [DataTracker.ROLL_TYPE_GREED] = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    [DataTracker.ROLL_TYPE_DISENCHANT] = "Interface\\Buttons\\UI-GroupLoot-DE-Up",
    [DataTracker.ROLL_TYPE_PASS] = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}

-- Priority order for sorting and provisional winner calculation (higher = higher priority)
local ROLL_PRIORITY = {
    [DataTracker.ROLL_TYPE_NEED] = 4,
    [DataTracker.ROLL_TYPE_GREED] = 3,
    [DataTracker.ROLL_TYPE_DISENCHANT] = 2,
    [DataTracker.ROLL_TYPE_PASS] = 1,
    [DataTracker.ROLL_TYPE_PENDING] = 0,
}

-- Active and recent roll sessions keyed by rollID
local rollsByID = {}
-- Ordered list of active rollIDs (oldest first)
local activeRollOrder = {}
-- Per-rollID dismissal state (closed via the [X] button for that specific item only)
local dismissedRolls = {}
-- Currently focused rollID in the companion UI
local currentRollID = nil

local chatPatterns = {}
local function Public(value)
    if not ns.IsSecretValue(value) then return value end
end

local function IsPositiveTime(value)
    return type(value) == "number" and value > 0 and value < math.huge
end

local function ReadTable(value)
    return not ns.IsSecretValue(value) and type(value) == "table" and (not canaccesstable or canaccesstable(value))
end

-- Convert a Blizzard format string (e.g. LOOT_ROLL_ROLLED_NEED = "%s rolls %d (%s)" or "%3$s rolls %1$d for %2$s")
-- into a Lua pattern + ordered capture map
local function CreatePatternFromGlobalString(globalStr, argOrder)
    if not globalStr or globalStr == "" then return nil end

    local effectiveOrder = {}
    local seqIdx = 0

    -- 1. Replace format specifiers (%s, %d, %1$s, %2$d) with safe placeholders BEFORE escaping Lua magic chars
    --    (otherwise escaping '$' to '%$' first breaks '%%%d*%$?s' and leaves '%1' in the pattern,
    --    which Lua's string.match interprets as an invalid capture index!)
    local prepared = globalStr:gsub("%%(%d*)%$?([sd])", function(posStr, specType)
        seqIdx = seqIdx + 1
        local argIdx = tonumber(posStr) or seqIdx
        if argOrder and argOrder[argIdx] then
            table.insert(effectiveOrder, argOrder[argIdx])
        end
        return (specType == "d") and "\2" or "\1"
    end)

    -- 2. Escape all Lua pattern magic characters (including any remaining literal % signs)
    local escaped = prepared:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")

    -- 3. Restore placeholders as valid Lua capture groups
    local pattern = escaped
        :gsub("\1", "(.+)")
        :gsub("\2", "(%%d+)")

    return {
        pattern = "^" .. pattern .. "$",
        order = (#effectiveOrder > 0) and effectiveOrder or argOrder,
    }
end

local function BuildChatPatterns()
    chatPatterns = {}

    local function AddGlobal(globalName, rollType, order, isSelf)
        local raw = _G[globalName]
        local entry = CreatePatternFromGlobalString(raw, order)
        if entry then
            entry.rollType = rollType
            entry.isSelf = isSelf
            table.insert(chatPatterns, entry)
        end
    end

    -- Roll result lines (e.g. "Need Roll - 94 for [Item] by Player")
    AddGlobal("LOOT_ROLL_ROLLED_NEED", DataTracker.ROLL_TYPE_NEED, { "roll", "item", "player" })
    AddGlobal("LOOT_ROLL_ROLLED_GREED", DataTracker.ROLL_TYPE_GREED, { "roll", "item", "player" })
    AddGlobal("LOOT_ROLL_ROLLED_DE", DataTracker.ROLL_TYPE_DISENCHANT, { "roll", "item", "player" })

    -- Choice selection lines (e.g. "Player has selected Need for: [Item]")
    AddGlobal("LOOT_ROLL_NEED", DataTracker.ROLL_TYPE_NEED, { "player", "item" })
    AddGlobal("LOOT_ROLL_GREED", DataTracker.ROLL_TYPE_GREED, { "player", "item" })
    AddGlobal("LOOT_ROLL_DISENCHANT", DataTracker.ROLL_TYPE_DISENCHANT, { "player", "item" })
    AddGlobal("LOOT_ROLL_PASSED", DataTracker.ROLL_TYPE_PASS, { "player", "item" })
    AddGlobal("LOOT_ROLL_PASSED_AUTO", DataTracker.ROLL_TYPE_PASS, { "player", "item" })
    AddGlobal("LOOT_ROLL_PASSED_AUTO_FEMALE", DataTracker.ROLL_TYPE_PASS, { "player", "item" })

    -- Self selection lines (e.g. "You have selected Need for: [Item]")
    AddGlobal("LOOT_ROLL_NEED_SELF", DataTracker.ROLL_TYPE_NEED, { "item" }, true)
    AddGlobal("LOOT_ROLL_GREED_SELF", DataTracker.ROLL_TYPE_GREED, { "item" }, true)
    AddGlobal("LOOT_ROLL_DISENCHANT_SELF", DataTracker.ROLL_TYPE_DISENCHANT, { "item" }, true)
    AddGlobal("LOOT_ROLL_PASSED_SELF", DataTracker.ROLL_TYPE_PASS, { "item" }, true)
    AddGlobal("LOOT_ROLL_PASSED_SELF_AUTO", DataTracker.ROLL_TYPE_PASS, { "item" }, true)

    -- Winner / completion announcements (e.g. "Player won: [Item]", "You won: [Item]", "Everyone passed on: [Item]")
    local function AddCompletionGlobal(globalName, order, isSelf, allPassed)
        local raw = _G[globalName]
        local entry = CreatePatternFromGlobalString(raw, order)
        if entry then
            entry.isCompletion = true
            entry.isSelf = isSelf
            entry.allPassed = allPassed
            table.insert(chatPatterns, entry)
        end
    end
    AddCompletionGlobal("LOOT_ROLL_WON", { "player", "item" }, false)
    AddCompletionGlobal("LOOT_ROLL_YOU_WON", { "item" }, true)
    AddCompletionGlobal("LOOT_ROLL_ALL_PASSED", { "item" }, false, true)
end

function DataTracker:GetRollTypeLabel(rollType)
    if rollType == self.ROLL_TYPE_NEED then
        return L.ROLL_NEED
    elseif rollType == self.ROLL_TYPE_GREED then
        return L.ROLL_GREED
    elseif rollType == self.ROLL_TYPE_DISENCHANT then
        return L.ROLL_DISENCHANT
    elseif rollType == self.ROLL_TYPE_PASS then
        return L.ROLL_PASS
    else
        return L.ROLL_PENDING
    end
end

function DataTracker:IsDismissed(rollID)
    return dismissedRolls[rollID] == true
end

function DataTracker:DismissRoll(rollID)
    if not rollID then return end
    dismissedRolls[rollID] = true

    -- If there is another non-dismissed active roll, switch to it; otherwise hide
    local nextRoll = self:GetNextVisibleRollID(rollID)
    if nextRoll then
        self:SetCurrentRollID(nextRoll)
    else
        if ns.RollTrackerFrame then
            ns.RollTrackerFrame:HideWindow()
        end
    end
end

function DataTracker:UndismissRoll(rollID)
    if not rollID then return end
    dismissedRolls[rollID] = nil
    local session = rollsByID[rollID]
    if session then
        session.manualShow = true
    end
end

function DataTracker:ScheduleAutoClose(rollID)
    if not rollID or rollID ~= currentRollID then return end
    local session = rollsByID[rollID]
    if not session or session.manualShow then return end

    local delay = ns:GetAutoCloseDelay()
    if not delay then return end

    if not session.completedAt then
        session.completedAt = GetTime()
    end

    local elapsed = GetTime() - session.completedAt
    local remaining = math.max(0.1, delay - elapsed)

    session._autoCloseGen = (session._autoCloseGen or 0) + 1
    local gen = session._autoCloseGen

    if C_Timer and C_Timer.After then
        C_Timer.After(remaining, function()
            if currentRollID ~= rollID then
                return
            end
            local s = rollsByID[rollID]
            if not s or s._autoCloseGen ~= gen or s.manualShow or dismissedRolls[rollID] then
                return
            end
            local curDelay = ns:GetAutoCloseDelay()
            if not curDelay then return end
            if s.completedAt and (GetTime() - s.completedAt) >= (curDelay - 0.05) then
                self:DismissRoll(rollID)
            end
        end)
    end
end

function DataTracker:TriggerAutoCloseForCompletedRolls()
    local session = self:GetCurrentRollSession()
    if session and not session.isClosed and not dismissedRolls[session.rollID] then
        local eval = self:EvaluateSession(session)
        if eval and eval.isComplete then
            session.manualShow = false
            session.completedAt = GetTime()
            self:ScheduleAutoClose(session.rollID)
        end
    end
end

function DataTracker:GetNextVisibleRollID(excludeRollID)
    local foundExcluded = false
    local firstAvailable = nil

    for i = 1, #activeRollOrder do
        local id = activeRollOrder[i]
        if id == excludeRollID then
            foundExcluded = true
        elseif not dismissedRolls[id] then
            local session = rollsByID[id]
            if session and not session.isClosed then
                if foundExcluded then
                    return id
                end
                if not firstAvailable then
                    firstAvailable = id
                end
            end
        end
    end
    return firstAvailable
end

function DataTracker:GetLastRollID()
    for i = #activeRollOrder, 1, -1 do
        local id = activeRollOrder[i]
        local session = rollsByID[id]
        if session and not session.isClosed then
            return id
        end
    end
    return nil
end

function DataTracker:GetActiveRolls()
    local list = {}
    for i = 1, #activeRollOrder do
        local id = activeRollOrder[i]
        local session = rollsByID[id]
        if session and not session.isClosed and not dismissedRolls[id] then
            table.insert(list, session)
        end
    end
    return list
end

function DataTracker:GetRollSession(rollID)
    return rollsByID[rollID]
end

function DataTracker:GetRollTimeLeft(session)
    if session and session.rollDeadline and not session.isDone and not session.isClosed then
        return math.max(0, session.rollDeadline - GetTime())
    end
end

function DataTracker:GetCurrentRollSession()
    if currentRollID and rollsByID[currentRollID] and not rollsByID[currentRollID].isClosed and not dismissedRolls[currentRollID] then
        return rollsByID[currentRollID]
    end
    local fallbackID = self:GetNextVisibleRollID()
    if fallbackID then
        currentRollID = fallbackID
        return rollsByID[currentRollID]
    end
    return nil
end

function DataTracker:SetCurrentRollID(rollID, forceShow)
    if not rollID or not rollsByID[rollID] then return end
    local changed = (currentRollID ~= rollID)
    currentRollID = rollID
    local session = rollsByID[rollID]
    if forceShow then
        dismissedRolls[rollID] = nil
    end
    if changed and session and session.completedAt then
        -- Give the newly focused tab a fresh auto-close countdown so the player has time to read it
        session.completedAt = GetTime()
        self:ScheduleAutoClose(rollID)
    end
    self:NotifyUI(forceShow)
end

function DataTracker:CreateOrUpdateRollSession(rollID, data)
    if not rollID then return nil end

    local isNew = (rollsByID[rollID] == nil)
    local session = rollsByID[rollID] or {
        rollID = rollID,
        itemLink = nil,
        itemName = nil,
        itemTexture = nil,
        itemQuality = 2,
        count = 1,
        players = {}, -- keyed by shortName -> { name, fullName, class, role, rollType, rollScore }
        numPlayers = 0,
        isDone = false,
        isClosed = false,
        isSimulated = false,
        startedAt = GetTime(),
    }

    if data then
        if data.itemLink then session.itemLink = data.itemLink end
        if data.itemName then session.itemName = data.itemName end
        if data.itemTexture then session.itemTexture = data.itemTexture end
        if data.itemQuality then session.itemQuality = data.itemQuality end
        if data.count then session.count = data.count end
        if data.isDone then session.isDone = true end
        if data.isSimulated ~= nil then session.isSimulated = data.isSimulated end
        if data.rollDeadline then session.rollDeadline = data.rollDeadline end
    end

    -- Populate initial eligible group roster if new real roll
    if isNew then
        rollsByID[rollID] = session
        table.insert(activeRollOrder, rollID)

        if not session.isSimulated then
            session.historyStartedAt = GetServerTime and GetServerTime() or time()
            session.historyRunID, session.historyRun, session.historyVisit = ns.History:GetRollRunID()
            local members = ns.RosterInspector:GetEligibleGroupMembers()
            for _, m in ipairs(members) do
                local short = ns.RosterInspector:GetShortName(m.name)
                session.players[short] = {
                    name = short,
                    fullName = m.fullName,
                    class = m.class,
                    role = m.role,
                    rollType = self.ROLL_TYPE_PENDING,
                    rollScore = nil,
                }
            end
        end

        -- A new item dropped! Reset dismissal for this new rollID and focus if none active
        dismissedRolls[rollID] = nil
        if not currentRollID or dismissedRolls[currentRollID] or (rollsByID[currentRollID] and rollsByID[currentRollID].isDone) then
            currentRollID = rollID
        end
    end

    return session
end

function DataTracker:SetPlayerRoll(rollID, playerName, classFile, rollType, rollScore, role, isSelf, rollDetail)
    local session = rollsByID[rollID]
    if not session or not playerName then return end

    local rosterInfo = session.isSimulated and { name = playerName, fullName = playerName, class = classFile, role = role }
        or ns.RosterInspector:GetPlayerInfo(playerName, classFile, role)
    local shortName = (rosterInfo and rosterInfo.name) or ns.RosterInspector:GetShortName(playerName)

    -- In WoW Forever, characters always have 2 names ("First Last").
    -- Prevent duplicate rows if one source reported only "First" and another reported "First Last".
    if ns.IsForever and not session.isSimulated then
        local firstWord, secondWord = shortName:match("^([^%s]+)%s+(.+)$")
        if firstWord and secondWord then
            -- If a single-name placeholder ("First") exists, upgrade and remove it
            local partial = session.players[firstWord]
            if partial and not session.players[shortName] then
                session.players[firstWord] = nil
                partial.name = shortName
                session.players[shortName] = partial
            elseif partial and session.players[shortName] then
                session.players[firstWord] = nil
            end
        else
            -- `shortName` has only 1 word ("First"); check if "First Last" is already in `session.players`
            for existingKey, existingEntry in pairs(session.players) do
                local exFirst = existingKey:match("^([^%s]+)%s+.+$")
                if exFirst and exFirst == shortName then
                    shortName = existingKey
                    break
                end
            end
        end
    end

    local entry = session.players[shortName]
    if not entry then
        entry = {
            name = shortName,
            fullName = rosterInfo.fullName or playerName,
            class = classFile or rosterInfo.class,
            role = role or rosterInfo.role or "NONE",
            rollType = self.ROLL_TYPE_PENDING,
            rollScore = nil,
        }
        session.players[shortName] = entry
    else
        if classFile then entry.class = classFile end
        if not entry.class and rosterInfo.class then entry.class = rosterInfo.class end
        if role and role ~= "NONE" then entry.role = role end
        if (not entry.role or entry.role == "NONE") and rosterInfo.role then
            entry.role = rosterInfo.role
        end
    end

    if rollType ~= nil and (rollType ~= self.ROLL_TYPE_PENDING or entry.rollType == self.ROLL_TYPE_PENDING) then
        if entry.rollType ~= rollType then entry.rollDetail = nil end
        entry.rollType = rollType
        entry.rollDetail = rollDetail or entry.rollDetail
    end
    if rollScore ~= nil then
        entry.rollScore = tonumber(rollScore)
    end
    local selfName = ns.RosterInspector:GetUnitNames("player")
    if isSelf == true or (selfName and shortName == selfName) then
        session.myChoice, session.myScore = entry.rollType, entry.rollScore
        entry.isSelf = true
    end
    return entry
end

function DataTracker:ConfirmResult(session, winner, allPassed)
    session.isDone = true
    session.resultConfirmed = true
    session.resultAt = session.resultAt or GetTime()
    if winner then
        local previous = session.winner
        if previous then
            if previous.isSelf then winner.isSelf = true end
            winner.name = winner.name or previous.name
            winner.choice = winner.choice or previous.choice
            winner.score = winner.score or previous.score
            if winner.name == previous.name then winner.class = winner.class or previous.class end
        end
        session.winner = winner
        session.allPassed = false
    elseif allPassed and not session.winner then
        session.allPassed = true
    end
    ns.History:Record(session)
    if session.winner and session.winner.isSelf and not session.winAnnounced then
        session.winAnnounced = true
        ns.RollEffects:ShowWin(session)
    end
end

-- Returns sorted array of player entries and summary statistics, including provisional winner
function DataTracker:EvaluateSession(session)
    if not session then return nil end

    local sortedPlayers = {}
    local totalPlayers = 0
    local answeredPlayers = 0

    for _, p in pairs(session.players) do
        totalPlayers = totalPlayers + 1
        if p.rollType ~= self.ROLL_TYPE_PENDING then
            answeredPlayers = answeredPlayers + 1
        end
        table.insert(sortedPlayers, p)
    end

    table.sort(sortedPlayers, function(a, b)
        local prioA = ROLL_PRIORITY[a.rollType] or 0
        local prioB = ROLL_PRIORITY[b.rollType] or 0
        if prioA ~= prioB then
            return prioA > prioB
        end
        local scoreA = a.rollScore or -1
        local scoreB = b.rollScore or -1
        if scoreA ~= scoreB then
            return scoreA > scoreB
        end
        return (a.name or "") < (b.name or "")
    end)

    -- Provisional winner calculation:
    -- Highest priority > PASS (Need > Greed > Disenchant) with highest numeric rollScore
    local bestType = nil
    local bestScore = -1
    local leaders = {}
    local anyNonPass = false

    for _, p in ipairs(sortedPlayers) do
        if p.rollType == self.ROLL_TYPE_NEED or p.rollType == self.ROLL_TYPE_GREED or p.rollType == self.ROLL_TYPE_DISENCHANT then
            anyNonPass = true
            local score = p.rollScore or 0
            if not bestType then
                bestType = p.rollType
                bestScore = score
                leaders = { p }
            elseif p.rollType == bestType then
                if score > bestScore then
                    bestScore = score
                    leaders = { p }
                elseif score == bestScore and score > 0 then
                    table.insert(leaders, p)
                end
            end
        end
    end

    local pendingCount = math.max(0, totalPlayers - answeredPlayers)
    local allScoresIn = true
    for _, p in ipairs(sortedPlayers) do
        if p.rollType == self.ROLL_TYPE_PENDING then
            allScoresIn = false
            break
        elseif (p.rollType == self.ROLL_TYPE_NEED or p.rollType == self.ROLL_TYPE_GREED or p.rollType == self.ROLL_TYPE_DISENCHANT) and not p.rollScore then
            allScoresIn = false
            break
        end
    end
    local isComplete = session.isDone
        or (not session.rollDeadline and totalPlayers > 0 and pendingCount == 0 and allScoresIn)

    if isComplete then
        if session.rollID == currentRollID then
            if not session.completedAt then
                session.completedAt = GetTime()
                self:ScheduleAutoClose(session.rollID)
            end
        end
    else
        session.completedAt = nil
    end

    return {
        players = sortedPlayers,
        totalPlayers = totalPlayers,
        answeredPlayers = answeredPlayers,
        pendingCount = pendingCount,
        isComplete = isComplete,
        bestType = bestType,
        bestScore = bestScore,
        leaders = leaders,
        allPassed = (not anyNonPass and answeredPlayers > 0 and pendingCount == 0),
    }
end

local function MapModernDropRollState(state, self)
    -- EncounterLootDropRollState: NeedMainSpec=0, NeedOffSpec=1, Transmog=2, Greed=3, NoRoll=4, Pass=5
    if state == 0 or state == 1 then
        return self.ROLL_TYPE_NEED
    elseif state == 2 or state == 3 then
        return self.ROLL_TYPE_GREED
    elseif state == 5 then
        return self.ROLL_TYPE_PASS
    else
        return self.ROLL_TYPE_PENDING
    end
end

function DataTracker:SyncModernDropInfo(dropInfo, encounterID, liveDrop)
    if not ReadTable(dropInfo) then return end
    local itemLink = Public(dropInfo.itemHyperlink)
    if type(itemLink) ~= "string" or itemLink == "" then return end

    local lootKey = Public(dropInfo.lootListKey)
    if type(lootKey) ~= "number" then return end
    encounterID = Public(encounterID)
    local dropKey = tostring(encounterID or "") .. ":" .. lootKey
    local targetRollID = "history:" .. dropKey
    local session = rollsByID[targetRollID]
    local ambiguous

    if not session then
        for i = #activeRollOrder, 1, -1 do
            local id = activeRollOrder[i]
            local candidate = rollsByID[id]
            if candidate and candidate.dropKey == dropKey then session, targetRollID = candidate, id; break end
        end
    end
    if not session then
        local match
        for _, id in ipairs(activeRollOrder) do
            local candidate = rollsByID[id]
            if candidate and not candidate.isSimulated and not candidate.dropKey
                and candidate.itemLink == itemLink then
                if match then match, ambiguous = nil, true; break end
                match = candidate
            end
        end
        if match then session, targetRollID = match, match.rollID end
    end

    local rawWinner = dropInfo.winner
    local winner = Public(rawWinner)
    local allPassed = Public(dropInfo.allPassed) == true
    local isDone = winner ~= nil or ns.IsSecretValue(rawWinner) or allPassed
    local started = Public(dropInfo.startTime)
    local observed
    if (liveDrop or (not isDone and not (session and session.rollDeadline)))
        and C_LootHistory.GetLootHistoryTime then
        local ok, value = pcall(C_LootHistory.GetLootHistoryTime)
        if ok then observed = Public(value) end
    end
    local elapsed = type(started) == "number" and type(observed) == "number" and observed - started
    local recent = type(elapsed) == "number" and elapsed >= 0 and elapsed <= 180
    if not session and isDone and not ambiguous and not recent then
        return
    end

    local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = ns.GetItemInfo(itemLink)
    if ambiguous and not isDone then return end
    local detached = ambiguous or (session and session.detached) or (not session and isDone)
    session = self:CreateOrUpdateRollSession(targetRollID, {
        itemLink = itemLink,
        itemName = itemName,
        itemQuality = itemQuality,
        itemTexture = itemTexture,
        isDone = isDone,
    })
    session.dropKey = dropKey
    if not session.rollDeadline and not session.isDone and type(elapsed) == "number" and elapsed >= 0 then
        local duration = Public(dropInfo.duration)
        if IsPositiveTime(duration) and (elapsed <= duration or (liveDrop and recent)) then
            session.rollDeadline = GetTime() + duration - elapsed
        end
    end
    if type(started) == "number" then
        local item = itemLink:match("|H(item:[^|]+)|h") or itemLink
        session.historyDropSignature = dropKey .. ":" .. tostring(started) .. ":" .. item
    end
    if not session.historySource and type(encounterID) == "number" and C_LootHistory.GetInfoForEncounter then
        local ok, encounter = pcall(C_LootHistory.GetInfoForEncounter, encounterID)
        if ok and ReadTable(encounter) then
            session.historySource = Public(encounter.encounterName)
        end
    end
    if detached then
        session.detached = true
        if currentRollID == targetRollID then currentRollID = nil end
        for index, id in ipairs(activeRollOrder) do
            if id == targetRollID then table.remove(activeRollOrder, index); break end
        end
    end

    local rollInfos = Public(dropInfo.rollInfos)
    if ReadTable(rollInfos) then
        for _, info in ipairs(rollInfos) do
            if ReadTable(info) then
                local name = Public(info.playerName)
                if type(name) == "string" and name ~= "" then
                    local detail = Public(info.state)
                    local state = MapModernDropRollState(detail, self)
                    self:SetPlayerRoll(targetRollID, name, Public(info.playerClass), state, Public(info.roll), nil, Public(info.isSelf), detail)
                end
            end
        end
    end
    if isDone then
        local result
        if ReadTable(winner) then
            local name, isSelf = Public(winner.playerName), Public(winner.isSelf) == true
            if type(name) == "string" or isSelf then
                result = { name = name, isSelf = isSelf, class = Public(winner.playerClass),
                    choice = MapModernDropRollState(Public(winner.state), self), score = Public(winner.roll) }
            end
        end
        if result and result.isSelf and session.myChoice == nil then
            session.myChoice, session.myScore = result.choice, result.score
        end
        self:ConfirmResult(session, result, allPassed)
    end
end

function DataTracker:SyncFromLootHistory(encounterID, lootListKey)
    if not C_LootHistory then
        return
    end

    -- 1. Classic Era / Anniversary / MoP C_LootHistory API
    if C_LootHistory.GetNumItems and C_LootHistory.GetItem then
        local numItems = C_LootHistory.GetNumItems() or 0
        for itemIdx = 1, numItems do
            local rollID, itemLink, numPlayers, isDone, winnerIdx, isMasterLoot = C_LootHistory.GetItem(itemIdx)
            if rollID and not isMasterLoot then
                local session = rollsByID[rollID]
                -- Only sync rolls that started during this session or are still active
                if session or not isDone then
                    local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = ns.GetItemInfo(itemLink or "")
                    session = self:CreateOrUpdateRollSession(rollID, {
                        itemLink = itemLink,
                        itemName = itemName,
                        itemQuality = itemQuality,
                        itemTexture = itemTexture,
                        isDone = isDone,
                    })

                    local winner
                    if session and numPlayers and numPlayers > 0 and C_LootHistory.GetPlayerInfo then
                        for playerIdx = 1, numPlayers do
                            local name, class, rollType, roll, isWinner, isMe = C_LootHistory.GetPlayerInfo(itemIdx, playerIdx)
                            if name and not ns.IsSecretValue(name) then
                                local mappedType = self.ROLL_TYPE_PENDING
                                if rollType == LOOT_ROLL_TYPE_NEED or rollType == 1 then
                                    mappedType = self.ROLL_TYPE_NEED
                                elseif rollType == LOOT_ROLL_TYPE_GREED or rollType == 2 then
                                    mappedType = self.ROLL_TYPE_GREED
                                elseif rollType == LOOT_ROLL_TYPE_DISENCHANT or rollType == 3 then
                                    mappedType = self.ROLL_TYPE_DISENCHANT
                                elseif rollType == LOOT_ROLL_TYPE_PASS or rollType == 0 then
                                    mappedType = self.ROLL_TYPE_PASS
                                end
                                self:SetPlayerRoll(rollID, name, Public(class), mappedType, Public(roll), nil, Public(isMe))
                                if Public(isWinner) == true or Public(winnerIdx) == playerIdx then
                                    winner = { name = name, isSelf = Public(isMe) == true, class = Public(class),
                                        choice = mappedType, score = Public(roll) }
                                end
                            end
                        end
                    end
                    if isDone then self:ConfirmResult(session, winner) end
                end
            end
        end
        self:NotifyUI()
        return
    end

    -- 2. WoW Forever (1.60.1) / Modern Encounter C_LootHistory API
    encounterID, lootListKey = Public(encounterID), Public(lootListKey)
    if encounterID and lootListKey and C_LootHistory.GetSortedInfoForDrop then
        local ok, dropInfo = pcall(C_LootHistory.GetSortedInfoForDrop, encounterID, lootListKey)
        if ok and ReadTable(dropInfo) then
            self:SyncModernDropInfo(dropInfo, encounterID, true)
            self:NotifyUI()
            return
        end
    end

    if encounterID and C_LootHistory.GetSortedDropsForEncounter then
        local ok, drops = pcall(C_LootHistory.GetSortedDropsForEncounter, encounterID)
        if ok and ReadTable(drops) then
            for _, dropInfo in ipairs(drops) do
                self:SyncModernDropInfo(dropInfo, encounterID)
            end
            self:NotifyUI()
            return
        end
    end

    if C_LootHistory.GetAllEncounterInfos and C_LootHistory.GetSortedDropsForEncounter then
        local ok, encounters = pcall(C_LootHistory.GetAllEncounterInfos)
        if ok and ReadTable(encounters) then
            for _, enc in ipairs(encounters) do
                local id = ReadTable(enc) and Public(enc.encounterID)
                if id then
                    local okDrops, drops = pcall(C_LootHistory.GetSortedDropsForEncounter, id)
                    if okDrops and ReadTable(drops) then
                        for _, dropInfo in ipairs(drops) do
                            self:SyncModernDropInfo(dropInfo, id)
                        end
                    end
                end
            end
        end
    end

    self:NotifyUI()
end

function DataTracker:OnStartLootRoll(rollID, rollTime)
    rollID = Public(rollID)
    if type(rollID) ~= "number" then return end
    rollTime = Public(rollTime)
    local remaining = rollTime
    if type(GetLootRollTimeLeft) == "function" then
        local ok, value = pcall(GetLootRollTimeLeft, rollID)
        if ok then
            value = Public(value)
            if IsPositiveTime(value) and (not IsPositiveTime(rollTime) or value <= rollTime) then remaining = value end
        end
    end
    local existing = self:GetRollSession(rollID)
    local deadline = (existing and existing.rollDeadline) or (IsPositiveTime(remaining) and GetTime() + remaining / 1000)
    local texture, name, count, quality
    if type(GetLootRollItemInfo) == "function" then
        texture, name, count, quality = GetLootRollItemInfo(rollID)
    end
    local link = type(GetLootRollItemLink) == "function" and GetLootRollItemLink(rollID) or nil

    self:CreateOrUpdateRollSession(rollID, {
        itemLink = link,
        itemName = name,
        itemTexture = texture,
        itemQuality = quality,
        count = count,
        isDone = false,
        isSimulated = false,
        rollDeadline = deadline,
    })

    -- Focus the newly started roll if autoOpen is enabled
    currentRollID = rollID
    self:SyncFromLootHistory()
    self:NotifyUI()
end

function DataTracker:OnCancelLootRoll(rollID)
    if ns.IsSecretValue(rollID) or not rollID then return end
    local session = rollsByID[rollID]
    if not session then return end

    self:SyncFromLootHistory()

    if not ns.db.keepOpenAfterMyRoll then
        session.isClosed = true
        if currentRollID == rollID then
            currentRollID = self:GetNextVisibleRollID(rollID)
        end
    end

    self:NotifyUI()
end

function DataTracker:OnChatMsgLoot(msg)
    if not msg or ns.IsSecretValue(msg) or type(msg) ~= "string" or msg == "" then return end

    for _, entry in ipairs(chatPatterns) do
        local c1, c2, c3 = msg:match(entry.pattern)
        if c1 then
            local captures = { c1, c2, c3 }
            local parsed = {}
            for idx, key in ipairs(entry.order) do
                parsed[key] = captures[idx]
            end

            local playerName = parsed.player
            if entry.isSelf then
                local myDisplayName = ns.RosterInspector:GetUnitNames("player")
                playerName = myDisplayName
            end
            local itemLink = parsed.item
            local rollScore = parsed.roll and tonumber(parsed.roll) or nil

            if itemLink and (entry.isCompletion or playerName) then
                local match
                for _, id in ipairs(activeRollOrder) do
                    local session = rollsByID[id]
                    if session and not session.isSimulated and session.itemLink == itemLink
                        and (not session.resultConfirmed or (session.resultAt and GetTime() - session.resultAt < 2)) then
                        if match then return end -- Chat does not identify which copy of an item was rolled.
                        match = session
                    end
                end
                if match then
                    if entry.isCompletion then
                        local winner = not entry.allPassed and (playerName or entry.isSelf)
                            and { name = playerName, isSelf = entry.isSelf } or nil
                        if winner and winner.isSelf and match.winner then
                            match.winner.isSelf = true
                        end
                        self:ConfirmResult(match, match.winner or winner, entry.allPassed)
                    else
                        self:SetPlayerRoll(match.rollID, playerName, nil, entry.rollType, rollScore, nil, entry.isSelf)
                        if match.resultConfirmed then ns.History:Record(match) end
                    end
                    self:NotifyUI()
                end
            end
            return
        end
    end
end

function DataTracker:ClearSimulatedRolls()
    local keptOrder = {}
    for _, id in ipairs(activeRollOrder) do
        local s = rollsByID[id]
        if s and s.isSimulated then
            rollsByID[id] = nil
            dismissedRolls[id] = nil
            if currentRollID == id then
                currentRollID = nil
            end
        else
            table.insert(keptOrder, id)
        end
    end
    activeRollOrder = keptOrder
    self:NotifyUI()
end

function DataTracker:NotifyUI(forceShow)
    if ns.MultiItemManager then
        ns.MultiItemManager:UpdateAnchoring()
    end
    if ns.RollTrackerFrame then
        ns.RollTrackerFrame:Refresh(forceShow)
    end
end

function DataTracker:Init()
    BuildChatPatterns()

    ns:RegisterEvent("START_LOOT_ROLL", function(_, rollID, rollTime)
        DataTracker:OnStartLootRoll(rollID, rollTime)
    end)

    ns:RegisterEvent("CANCEL_LOOT_ROLL", function(_, rollID)
        DataTracker:OnCancelLootRoll(rollID)
    end)

    ns:RegisterEvent("LOOT_HISTORY_AUTO_SHOW", function()
        DataTracker:SyncFromLootHistory()
    end)

    ns:RegisterEvent("LOOT_HISTORY_ROLL_CHANGED", function()
        DataTracker:SyncFromLootHistory()
    end)

    ns:RegisterEvent("LOOT_HISTORY_ROLL_COMPLETE", function()
        DataTracker:SyncFromLootHistory()
    end)

    ns:RegisterEvent("LOOT_HISTORY_FULL_UPDATE", function()
        DataTracker:SyncFromLootHistory()
    end)

    -- WoW Forever (1.60.1) / Modern Encounter Loot History events
    ns:RegisterEvent("LOOT_HISTORY_UPDATE_DROP", function(_, encounterID, lootListKey)
        DataTracker:SyncFromLootHistory(encounterID, lootListKey)
    end)

    ns:RegisterEvent("LOOT_HISTORY_UPDATE_ENCOUNTER", function(_, encounterID)
        DataTracker:SyncFromLootHistory(encounterID)
    end)

    ns:RegisterEvent("CHAT_MSG_LOOT", function(_, msg)
        DataTracker:OnChatMsgLoot(msg)
    end)
end
