local addonName, ns = ...
local L = ns.L
local DataTracker = ns.DataTracker

local Simulator = {}
ns.Simulator = Simulator

local simCounter = 0
local activeTimers = {}
local pendingWinPreview
local MAX_GROUP_SIZE = 40

local MOCK_ITEMS = {
    {
        itemID = 5191,
        texture = "Interface\\Icons\\INV_Sword_24",
        quality = 3,
    },
    {
        itemID = 6460,
        texture = "Interface\\Icons\\INV_Belt_03",
        quality = 3,
    },
    {
        itemID = 11992,
        texture = "Interface\\Icons\\INV_Jewelry_Ring_03",
        quality = 2,
    },
    {
        itemID = 5201,
        texture = "Interface\\Icons\\INV_Staff_13",
        quality = 3,
    },
}

local MOCK_CLASSES = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"
}

local MOCK_ROLES = {
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER"
}

local function CancelAllTimers()
    for _, t in ipairs(activeTimers) do
        if t and t.Cancel then
            t:Cancel()
        end
    end
    activeTimers = {}
end

local function ScheduleTimer(delay, callback)
    if C_Timer and C_Timer.NewTimer then
        local handle = C_Timer.NewTimer(delay, callback)
        table.insert(activeTimers, handle)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay, callback)
    else
        callback()
    end
end

local function ResolveMockItemInfo(mockItem, onResolved)
    local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = ns.GetItemInfo(mockItem.itemID)
    if itemName and itemLink then
        return {
            itemID = mockItem.itemID,
            name = itemName,
            link = itemLink,
            texture = itemTexture or mockItem.texture,
            quality = itemQuality or mockItem.quality,
        }
    end

    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, mockItem.itemID)
    end

    -- Replace the placeholder once the client can supply the name and link.
    if Item and Item.CreateFromItemID then
        local ok, itemObj = pcall(Item.CreateFromItemID, Item, mockItem.itemID)
        if ok and itemObj and itemObj.ContinueOnItemLoad then
            itemObj:ContinueOnItemLoad(function()
                local loadedName, loadedLink, loadedQuality, _, _, _, _, _, _, loadedTexture = ns.GetItemInfo(mockItem.itemID)
                if onResolved and loadedName and loadedLink then
                    onResolved(loadedName, loadedLink, loadedTexture, loadedQuality)
                end
            end)
        end
    end

    return {
        itemID = mockItem.itemID,
        name = L.TEST_ITEM_FALLBACK:format(mockItem.itemID),
        link = nil, -- Only attach hyperlink once server confirms item exists in this client's database
        texture = mockItem.texture,
        quality = mockItem.quality,
    }
end

function Simulator:PreviewWin()
    local mode = ns.db.winNotification
    if mode == "OFF" then return end

    local function Show(name, link, texture, quality)
        if pendingWinPreview ~= Show then return end
        pendingWinPreview = nil
        if ns.db.winNotification ~= mode then return end
        ns.RollEffects:PreviewWin({
            itemName = name,
            itemLink = link,
            itemTexture = texture or MOCK_ITEMS[1].texture,
            itemQuality = quality or MOCK_ITEMS[1].quality,
        })
    end

    pendingWinPreview = Show
    local item = ResolveMockItemInfo(MOCK_ITEMS[1], Show)
    if item.link or not ns:ShowsBlizzardWin() then
        Show(item.name, item.link, item.texture, item.quality)
    else
        C_Timer.After(3, function() Show(item.name, nil, item.texture, item.quality) end)
    end
end

local function SpawnSimulatedItemRoll(mockItem, baseDelay, groupSize, scenario)
    simCounter = simCounter + 1
    local rollID = "test:" .. simCounter
    local timeout = scenario == "TIMEOUT"
    local allPass = scenario == "PASS"
    local winnerIndex = scenario == "OTHER" and 2 or 1
    local duration = (timeout and 12 or 18) + baseDelay

    local resolved = ResolveMockItemInfo(mockItem, function(loadedName, loadedLink, loadedTexture, loadedQuality)
        local s = DataTracker:GetRollSession(rollID)
        if s then
            s.itemName = loadedName
            s.itemLink = loadedLink
            if loadedTexture then s.itemTexture = loadedTexture end
            if loadedQuality then s.itemQuality = loadedQuality end
            DataTracker:NotifyUI()
        end
    end)

    local session = DataTracker:CreateOrUpdateRollSession(rollID, {
        itemLink = resolved.link,
        itemName = resolved.name,
        itemTexture = resolved.texture,
        itemQuality = resolved.quality,
        count = 1,
        isDone = false,
        isSimulated = true,
        rollDeadline = GetTime() + duration,
    })

    -- Include the actual player + mock party/raid members up to targetSize
    local myDisplayName = ns.RosterInspector:GetUnitNames("player")
    local myName = (myDisplayName and myDisplayName ~= "") and myDisplayName or L.TEST_SELF_NAME
    local _, rawClass = UnitClass("player")
    local myClass = (rawClass and not ns.IsSecretValue(rawClass)) and rawClass or "PALADIN"
    local myRole = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if ns.IsSecretValue(myRole) or not myRole or myRole == "NONE" then myRole = "DAMAGER" end

    local roster = {
        { name = myName, class = myClass or "PALADIN", role = myRole },
    }
    for i = 1, groupSize do
        if #roster >= groupSize then break end
        local name = L.TEST_MEMBER_NAME:format(i)
        if name ~= myName then
            table.insert(roster, {
                name = name,
                class = MOCK_CLASSES[((i - 1) % #MOCK_CLASSES) + 1],
                role = MOCK_ROLES[((i - 1) % #MOCK_ROLES) + 1],
            })
        end
    end

    for _, p in ipairs(roster) do
        DataTracker:SetPlayerRoll(rollID, p.name, p.class, DataTracker.ROLL_TYPE_PENDING, nil, p.role)
    end

    local choices = {
        DataTracker.ROLL_TYPE_NEED,
        DataTracker.ROLL_TYPE_GREED,
        DataTracker.ROLL_TYPE_GREED,
        DataTracker.ROLL_TYPE_PASS,
        DataTracker.ROLL_TYPE_PASS,
        DataTracker.ROLL_TYPE_PASS,
    }

    local responders = #roster - (timeout and 2 or 0)
    for idx = 1, responders do
        local p = roster[idx]
        local delay = baseDelay + 0.35 + (idx - 1) * 5 / (responders - 1)
        ScheduleTimer(delay, function()
            local current = DataTracker:GetRollSession(rollID)
            if not current or current.isClosed then return end

            local choice, score
            if allPass then
                choice = DataTracker.ROLL_TYPE_PASS
            elseif idx == winnerIndex then
                choice, score = DataTracker.ROLL_TYPE_NEED, 100
            else
                choice = choices[((idx - 1) % #choices) + 1]
                if choice ~= DataTracker.ROLL_TYPE_PASS then score = math.random(1, 99) end
            end
            DataTracker:SetPlayerRoll(rollID, p.name, p.class, choice, score, p.role, idx == 1)
            DataTracker:NotifyUI()
        end)
    end

    local resultDelay = timeout and duration + 1 or baseDelay + 5.65
    ScheduleTimer(resultDelay, function()
        local current = DataTracker:GetRollSession(rollID)
        if not current or current.isClosed then return end
        local winner = not allPass and {
            name = roster[winnerIndex].name,
            isSelf = winnerIndex == 1,
            choice = DataTracker.ROLL_TYPE_NEED,
            score = 100,
        } or nil
        DataTracker:ConfirmResult(current, winner, allPass)
        DataTracker:NotifyUI()
    end)

    return rollID
end

function Simulator:StartTest(itemCount, groupSize, scenario)
    itemCount = math.floor(math.max(1, math.min(#MOCK_ITEMS, tonumber(itemCount) or 1)))
    groupSize = math.floor(math.max(5, math.min(MAX_GROUP_SIZE, tonumber(groupSize) or 5)))
    CancelAllTimers()
    DataTracker:ClearSimulatedRolls()

    local firstRollID
    for i = 1, itemCount do
        local id = SpawnSimulatedItemRoll(MOCK_ITEMS[i], (i - 1) * 0.7, groupSize, scenario)
        if i == 1 then firstRollID = id end
    end

    DataTracker:SetCurrentRollID(firstRollID, true)
    if ns.Settings then ns.Settings:UpdateTestActions(true) end
    ns:Print(string.format(L.MSG_SIM_STARTED, itemCount))
end

function Simulator:StartSingleTest()
    self:StartTest(1, 5, "SELF")
end

function Simulator:StartRaidTest(raidSize)
    self:StartTest(1, raidSize or 40, "OTHER")
end

function Simulator:StartMultiTest()
    self:StartTest(#MOCK_ITEMS, 5, "OTHER")
end

function Simulator:StopTests()
    CancelAllTimers()
    DataTracker:ClearSimulatedRolls()
    if ns.Settings then ns.Settings:UpdateTestActions(false) end
    ns:Print(L.MSG_SIM_STOPPED)
end
