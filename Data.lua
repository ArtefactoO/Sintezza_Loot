local addonName, ns = ...
local L, H = ns.L, ns.History
local Transfer = Sintezza_Theme.DataTransfer
local ROLL_LIMIT, IMPORT_ROW_LIMIT = 400, 840

local function Plain(value, max)
    return type(value) == "string" and #value > 0 and #value <= max and not value:find("[%z\001-\031\127|]")
end

local function Number(value, minimum, maximum)
    return type(value) == "number" and value >= minimum and value <= maximum
end

local function Integer(value, minimum, maximum)
    return Number(value, minimum, maximum) and value == math.floor(value)
end

local function Character(value)
    return Plain(value, 64) and value:match("^Player%-%d+%-%x+$")
end

local function Shape(value, fields)
    if type(value) ~= "table" then return false end
    for key, field in pairs(value) do
        if not fields[key] or not fields[key](field) then return false end
    end
    return true
end

local function Name(value) return Plain(value, 240) end
local function Stamp(value) return Integer(value, 1, 1e11) end
local function Positive(value) return Integer(value, 1, 1e9) end
local function Nonnegative(value) return Integer(value, 0, 1e9) end
local function Class(value) return Plain(value, 28) and value:match("^[A-Z]+$") end
local function Boolean(value) return type(value) == "boolean" end
local function Choice(value) return Integer(value, -1, 3) end
local function RollDetail(value) return Integer(value, 0, 5) end
local function Score(value) return Integer(value, 0, 1000000) end
local function Texture(value)
    return Positive(value) or Plain(value, 300)
end
local function Item(value)
    if type(value) ~= "string" or #value > 1024 or value:find("[%z\001-\031\127]") then return false end
    local link = value:gsub("^|c%x%x%x%x%x%x%x%x", ""):gsub("^|cn[A-Z0-9_]+:", ""):gsub("|r$", "")
    return link:match("^|Hitem:[%d:%-]+|h%[[^|]*%]|h$") ~= nil
end

local winnerFields = { name = Name, class = Class, isSelf = Boolean, choice = Choice, score = Score }
local playerFields = { name = Name, class = Class, isSelf = Boolean, choice = Choice, score = Score, rollDetail = RollDetail }
local function Winner(value)
    return Shape(value, winnerFields) and (value.name or value.isSelf == true)
end
local function Players(value)
    if type(value) ~= "table" or #value > 80 then return false end
    local length = #value
    for index, player in pairs(value) do
        if not Integer(index, 1, length) or not Shape(player, playerFields) or not player.name then return false end
    end
    for index = 1, length do if not value[index] then return false end end
    return true
end

local function RunKind(value) return value == "party" or value == "raid" end
local function EndReason(value)
    return value == "completed" or value == "reset" or value == "left" or value == "imported" or value == "manual"
end
local function BossNames(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for name, dead in pairs(value) do
        count = count + 1
        if count > 100 or not Name(name) or not Boolean(dead) then return false end
    end
    return true
end
local function EncounterKills(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for id, dead in pairs(value) do
        count = count + 1
        if count > 100 or not Positive(id) or dead ~= true then return false end
    end
    return true
end
local runFields = {
    name = Name, kind = RunKind, difficulty = Nonnegative, mapID = Positive, character = Character,
    startedAt = Stamp, endedAt = Stamp, endReason = EndReason,
    instanceCopy = function(value) return Plain(value, 80) and value:match("^[%d%-]+$") end,
    lockoutKey = function(value) return Plain(value, 80) and value:match("^%d+:%d+$") end,
    killedEncounters = EncounterKills, killedBossNames = BossNames, lockProgress = BossNames,
    progressLocale = function(value) return Plain(value, 10) end,
}
local function Run(value)
    return Shape(value, runFields) and value.name and value.kind and value.mapID and value.startedAt and value.character
        and (not value.endedAt or value.endedAt >= value.startedAt)
end
local rollFields = {
    time = Stamp, character = Character, outside = Boolean, name = Name, link = Item, icon = Texture,
    quality = function(value) return Integer(value, 0, 10) end,
    source = Name, sourceJournalID = Positive, winner = Winner, allPassed = Boolean, choice = Choice, score = Score, players = Players,
    attemptItemID = Positive,
    dropSignature = function(value)
        return type(value) == "string" and #value <= 1200 and not value:find("[%z\001-\031\127]")
    end,
}
local function Roll(value)
    if not Shape(value, rollFields) or not value.time or not (value.name or value.link) then return false end
    local itemID = value.link and tonumber(value.link:match("|Hitem:(%d+)"))
    return (not value.attemptItemID or value.attemptItemID == itemID) and not (value.allPassed and value.winner)
end

local function Pick(value, fields)
    local result = {}
    for key in pairs(fields) do result[key] = value[key] end
    return result
end

local function Key(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local value = tostring(select(i, ...) or "")
        parts[i] = #value .. ":" .. value
    end
    return table.concat(parts)
end

local function RunID(run)
    return Key(run.character, run.mapID, run.difficulty, run.kind, run.startedAt, run.name)
end

local function RollKey(roll, run)
    if roll.character and roll.dropSignature and roll.dropSignature ~= "" then return Key(roll.character, roll.dropSignature) end
    local winner = roll.winner
    return Key(roll.character, roll.time, roll.link or roll.name, run and RunID(run), roll.outside,
        winner and winner.name, winner and winner.isSelf, roll.allPassed)
end

local function RollID(roll, run, sequence)
    local key = RollKey(roll, run)
    sequence[key] = (sequence[key] or 0) + 1
    return Key(key, sequence[key])
end

local function Result(roll)
    if roll.allPassed then return "all_passed" end
    if roll.winner then return roll.winner.isSelf and "self_win" or "winner" end
    return "unknown"
end

local function Values(kind, id, record, run, payload)
    local stamp = kind == "roll" and record.time or record.startedAt
    local itemID = record.link and tonumber(record.link:match("|Hitem:(%d+)"))
    return { kind, id, stamp, itemID or "", kind == "roll" and Result(record) or (record.endReason or ""),
        record.character or "", run and run.name or "", record.winner and record.winner.name or "", payload }
end

local function Export(scope)
    local rows, index, mine = {}, {}, {}
    if scope == "mine" then
        for _, roll in ipairs(H:FindPersonalLoot("")) do mine[roll] = true end
    end
    if scope == "all" or scope == "runs" then
        for _, run in pairs(ns.db.lootRuns) do
            local data = Pick(run, runFields)
            local payload, problem = Transfer:EncodeRecord(data)
            if not payload then return nil, problem end
            rows[#rows + 1] = Values("run", RunID(data), data, data, payload)
        end
        table.sort(rows, function(a, b) return a[2] < b[2] end)
    end
    if scope == "all" or scope == "rolls" or scope == "mine" then
        for _, roll in ipairs(ns.db.rollHistory) do
            local run = roll.runID and ns.db.lootRuns[roll.runID]
            local id = RollID(roll, run, index)
            if scope ~= "mine" or mine[roll] then
                local data = Pick(roll, rollFields)
                if data.winner then
                    data.winner = Pick(data.winner, winnerFields)
                    data.winner.class = H:GetWinnerClass(roll)
                end
                local payload, problem = Transfer:EncodeRecord({ roll = data, run = run and Pick(run, runFields) })
                if not payload then return nil, problem end
                rows[#rows + 1] = Values("roll", id, data, run, payload)
            end
        end
    end
    return rows
end

local function ActiveIDs()
    local ids = {}
    for _, id in pairs(ns.db.activeLootRuns) do ids[id] = true end
    for _, id in pairs(ns.db.lootRunPresence) do ids[id] = true end
    if H.insideRunID then ids[H.insideRunID] = true end
    return ids
end

local function Stage(rows)
    if #rows > IMPORT_ROW_LIMIT then return nil, L.DATA_LIMIT end
    local knownRuns, knownRolls, index, occupied = {}, {}, {}, {}
    for id, run in pairs(ns.db.lootRuns) do knownRuns[RunID(run)] = id end
    for _, roll in ipairs(ns.db.rollHistory) do
        local run = roll.runID and ns.db.lootRuns[roll.runID]
        knownRolls[RollID(roll, run, index)] = true
        if run then occupied[RunID(run)] = true end
    end
    local plan = { added = 0, duplicates = 0, runs = {}, rolls = {}, runIDs = knownRuns }
    local function AddRun(run)
        local id = RunID(run)
        if knownRuns[id] then return end
        knownRuns[id] = true
        plan.runs[#plan.runs + 1] = run
        plan.added = plan.added + 1
        return id
    end
    for _, row in ipairs(rows) do
        local kind, id = row[1], row[2]
        local data = Transfer:DecodeRecord(row[9])
        local record, run
        if kind == "run" and Run(data) and id == RunID(data) then
            record, run = data, data
        elseif kind == "roll" and Shape(data, { roll = Roll, run = Run }) and data.roll then
            record, run = data.roll, data.run
            if run and (record.outside or (record.character and record.character ~= run.character)) then
                return nil, L.DATA_INVALID
            end
            local key = RollKey(record, run)
            local prefix = #key .. ":" .. key
            local serial = tonumber(id:sub(#prefix + 1):match("^%d+:(%d+)$"))
            if not Integer(serial, 1, ROLL_LIMIT) or id ~= Key(key, serial) then return nil, L.DATA_INVALID end
        else
            return nil, L.DATA_INVALID
        end
        local expected = Values(kind, id, record, run, row[9])
        for column = 1, 8 do
            if tostring(expected[column]) ~= tostring(row[column]) then return nil, L.DATA_INVALID end
        end
        if kind == "run" then
            if not AddRun(run) then plan.duplicates = plan.duplicates + 1 end
        elseif knownRolls[id] then
            plan.duplicates = plan.duplicates + 1
        else
            if run then
                AddRun(run)
                occupied[RunID(run)] = true
            end
            knownRolls[id] = true
            plan.rolls[#plan.rolls + 1] = { record = record, run = run and RunID(run) }
            plan.added = plan.added + 1
        end
    end
    local skipped = 0
    for index = #plan.runs, 1, -1 do
        if not occupied[RunID(plan.runs[index])] then
            table.remove(plan.runs, index)
            plan.added, skipped = plan.added - 1, skipped + 1
        end
    end
    if skipped > 0 then plan.message = L.DATA_IMPORT_EMPTY:format(plan.added, plan.duplicates, skipped) end
    if #ns.db.rollHistory + #plan.rolls > ROLL_LIMIT then return nil, L.DATA_LIMIT end
    return plan
end

local function Apply(plan)
    local db = ns.db
    for _, run in ipairs(plan.runs) do
        db.nextLootRunID = db.nextLootRunID + 1
        run.id = db.nextLootRunID
        run.endReason = run.endReason or "imported"
        db.lootRuns[run.id] = run
        plan.runIDs[RunID(run)] = run.id
    end
    for _, row in ipairs(plan.rolls) do
        row.record.runID = row.run and plan.runIDs[row.run]
        table.insert(db.rollHistory, row.record)
    end
    local order = {}
    for index, roll in ipairs(db.rollHistory) do order[roll] = index end
    table.sort(db.rollHistory, function(a, b)
        if a.time ~= b.time then return a.time > b.time end
        return order[a] < order[b]
    end)
    H:TrimRuns()
    return true
end

function H:GetDataCounts()
    local runs = 0
    for _ in pairs(ns.db.lootRuns) do runs = runs + 1 end
    return { runs, #ns.db.rollHistory, #H:FindPersonalLoot("") }
end

local function ArchiveCount()
    local count, active = 0, ActiveIDs()
    for id in pairs(ns.db.lootRuns) do if not active[id] then count = count + 1 end end
    return count
end

local function ClearArchive()
    local db, active = ns.db, ActiveIDs()
    for id in pairs(db.lootRuns) do if not active[id] then db.lootRuns[id] = nil end end
    for _, roll in ipairs(db.rollHistory) do
        if roll.runID and not db.lootRuns[roll.runID] then roll.runID = nil end
    end
    return true
end

local function ClearMine()
    local mine = {}
    for _, roll in ipairs(H:FindPersonalLoot("")) do mine[roll] = true end
    H:RemoveRolls(function(roll) return mine[roll] end)
    if H.character then ns.db.lootAttemptCarry[H.character] = nil end
    return true
end

ns.DataTransferSpec = {
    addon = addonName,
    title = L.HISTORY_TITLE,
    note = L.DATA_MEMORY_NOTE,
    columns = { "type", "id", "time", "item_id", "result", "character", "run", "winner", "payload" },
    scopes = {
        { key = "all", label = L.DATA_ALL }, { key = "runs", label = L.HISTORY_RUNS },
        { key = "rolls", label = L.DATA_ROLLS }, { key = "mine", label = L.HISTORY_PERSONAL },
    },
    export = Export,
    stage = Stage,
    apply = Apply,
    sections = {
        { label = L.DATA_ARCHIVED, count = ArchiveCount, clear = ClearArchive },
        { label = L.DATA_ROLLS, count = function() return #ns.db.rollHistory end, clear = function()
            H:RemoveRolls(function() return true end)
            ns.db.lootAttemptCarry = {}
            return true
        end },
        { label = L.HISTORY_PERSONAL, count = function() return #H:FindPersonalLoot("") end, clear = ClearMine },
    },
    changed = function()
        H:UpdateView()
        if ns.Settings.RefreshData then ns.Settings:RefreshData() end
    end,
}
