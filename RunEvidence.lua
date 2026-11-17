local _, ns = ...
local H = ns.History

local function Public(value)
    if not ns.IsSecretValue(value) then return value end
end

local function Integer(value, minimum, maximum)
    return type(value) == "number" and value >= minimum and value <= maximum and value == math.floor(value)
end

local function Name(value)
    return type(value) == "string" and #value > 0 and #value <= 240 and not value:find("[%z\001-\031\127|]")
end

local function CurrentRun()
    H:ObserveInstance()
    local run = H:GetRun(H.insideRunID)
    if not run or type(GetInstanceInfo) ~= "function" then return end
    local _, kind, difficulty, _, _, _, _, mapID = GetInstanceInfo()
    if Public(mapID) == run.mapID and Public(difficulty) == run.difficulty and Public(kind) == run.kind then return run end
end

local function CanComplete()
    local active = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
    return type(active) ~= "function" or Public(active()) == false
end

function H:RequestLockInfo()
    if not self.visit or not self.insideRunID or type(RequestRaidInfo) ~= "function" then return end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        self.requestLockInfoAfterCombat = true
        return
    end
    self.requestLockInfoAfterCombat = nil
    self.lockRequestVisitID = self.visit.id
    RequestRaidInfo()
end

function H:ObserveSavedLock()
    local run = CurrentRun()
    if not run or not self.visit or self.lockRequestVisitID ~= self.visit.id
        or type(GetNumSavedInstances) ~= "function" or type(GetSavedInstanceInfo) ~= "function" then return end
    local count = Public(GetNumSavedInstances())
    if not Integer(count, 0, 200) then return end
    local key
    for index = 1, count do
        local _, low, _, difficulty, locked, _, high, raid, _, _, _, _, _, mapID = GetSavedInstanceInfo(index)
        low, high, difficulty, locked, raid, mapID = Public(low), Public(high), Public(difficulty),
            Public(locked), Public(raid), Public(mapID)
        if mapID == run.mapID and difficulty == run.difficulty and raid == (run.kind == "raid") and locked == true then
            if key or not Integer(low, 1, 9007199254740991) or not Integer(high, 0, 9007199254740991) then return end
            key = ("%.0f:%.0f"):format(high, low)
        end
    end
    -- Missing or unlocked rows do not establish that the current copy was reset.
    if not key then return end
    local previous = self.visit.baselineLockoutKey
    if previous and previous ~= key then run = self:SplitVisit("reset") end
    if run then
        run.lockoutKey = key
        self:SaveVisit()
        self:CheckEncounterCompletion()
    end
end

function H:ObserveLockProgress()
    if not self.lockPrompt then return end
    local run = CurrentRun()
    if not run or type(GetInstanceLockTimeRemaining) ~= "function"
        or type(GetInstanceLockTimeRemainingEncounter) ~= "function" then return end
    local _, _, total, completed = GetInstanceLockTimeRemaining()
    total, completed = Public(total), Public(completed)
    if not Integer(total, 1, 100) or not Integer(completed, 0, total) then return end
    local progress, killed = {}, 0
    for index = 1, total do
        local name, _, dead = GetInstanceLockTimeRemainingEncounter(index)
        name, dead = Public(name), Public(dead)
        if not Name(name) or type(dead) ~= "boolean" or progress[name] ~= nil then return end
        progress[name] = dead
        if dead then killed = killed + 1 end
    end
    if killed ~= completed then return end
    local locale = GetLocale()
    local changed
    local visit = self.visit
    if visit and visit.baselineLocale == locale then
        for name, dead in pairs(progress) do
            if not dead and visit.baselineDead and visit.baselineDead[name] then changed = true; break end
        end
    end
    if changed then run = self:SplitVisit("reset") end
    if not run then return end
    run.lockProgress, run.progressLocale = progress, locale
    if completed == total and CanComplete() then self:Archive("completed") end
end

function H:CheckEncounterCompletion()
    local run = self:GetActiveRun()
    if not run or run.id ~= self.insideRunID or not run.killedEncounters or not CanComplete() then return end
    if not (C_EncounterJournal and type(C_EncounterJournal.GetInstanceForGameMap) == "function"
        and type(EJ_GetEncounterInfoByIndex) == "function") then return end
    local journalID = Public(C_EncounterJournal.GetInstanceForGameMap(run.mapID))
    if not Integer(journalID, 1, 1e9) then return end
    for index = 1, 101 do
        local name, _, _, _, _, _, id = EJ_GetEncounterInfoByIndex(index, journalID)
        if ns.IsSecretValue(name) then return end
        if name == nil then
            if index > 1 then self:Archive("completed") end
            return
        end
        id = Public(id)
        if not Name(name) or not Integer(id, 1, 1e9) or not run.killedEncounters[id] then return end
    end
end

function H:RecordEncounter(encounterID, name)
    encounterID, name = Public(encounterID), Public(name)
    if not Integer(encounterID, 1, 1e9) then return end
    local run = CurrentRun()
    if not run then return end
    local visit = self.visit
    visit.killedEncounters, visit.previousKills = visit.killedEncounters or {}, visit.previousKills or {}
    run.killedEncounters = run.killedEncounters or {}
    if visit.previousKills[encounterID] == nil then visit.previousKills[encounterID] = run.killedEncounters[encounterID] == true end
    visit.killedEncounters[encounterID] = true
    run.killedEncounters[encounterID] = true
    local locale = GetLocale()
    if run.progressLocale ~= locale then
        run.killedBossNames, run.lockProgress = nil, nil
        run.progressLocale = locale
    end
    if Name(name) then
        visit.killedBossNames, visit.previousNames = visit.killedBossNames or {}, visit.previousNames or {}
        run.killedBossNames = run.killedBossNames or {}
        if visit.previousNames[name] == nil then visit.previousNames[name] = run.killedBossNames[name] == true end
        visit.killedBossNames[name] = true
        run.killedBossNames[name] = true
    end
    self:SaveVisit()
    self:CheckEncounterCompletion()
    self:RequestLockInfo()
end

function H:InitRunEvidence()
    ns:RegisterEvent("ENCOUNTER_END", function(_, id, name, _, _, success)
        if Public(success) == 1 then self:RecordEncounter(id, name) end
    end)
    ns:RegisterEvent("BOSS_KILL", function(_, id, name) self:RecordEncounter(id, name) end)
    ns:RegisterEvent("UPDATE_INSTANCE_INFO", function()
        self:ObserveSavedLock()
        self:ObserveLockProgress()
    end)
    for _, event in ipairs({ "INSTANCE_LOCK_START", "INSTANCE_LOCK_WARNING" }) do
        ns:RegisterEvent(event, function()
            self:ObserveInstance()
            self.lockPrompt = self.insideRunID ~= nil
            self:ObserveLockProgress()
        end)
    end
    ns:RegisterEvent("INSTANCE_LOCK_STOP", function() self.lockPrompt = nil end)
    ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if self.requestLockInfoAfterCombat then self:RequestLockInfo() end
    end)
end
