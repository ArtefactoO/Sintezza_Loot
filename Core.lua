local addonName, ns = ...
local L = ns.L
ns.ICON = Sintezza_Theme.icons.Sintezza_Loot


local rawVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")
    or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
if not rawVersion or rawVersion:find("project%-version") then
    rawVersion = "1.5.0"
end
ns.VERSION = rawVersion
ns.DEFAULT_AUTO_CLOSE_DELAY = 10

local DEFAULT_SETTINGS = {
    enabled = true,
    autoOpen = true,
    showRoleIcons = true,
    showRollTimer = true,
    autoSwitchOnHover = true,
    keepOpenAfterMyRoll = true,
    hidePassed = false,
    hidePending = false,
    animateNewRoll = true,
    choiceDisplay = "ICONS", -- "ICONS", "TEXT", or "BOTH"
    autoCloseDelay = ns.DEFAULT_AUTO_CLOSE_DELAY,
    windowOpacity = 100,     -- 20..100 (%)
    windowScale = 100,       -- 60..160 (%)
    anchorSide = "RIGHT",    -- "RIGHT", "LEFT", or "FREE"
    freePosition = nil,      -- { point = "CENTER", relativePoint = "CENTER", x = 220, y = 0 }
    testItemCount = 1,
    testGroupSize = 5,
    testScenario = "TIMEOUT",
}

local eventFrame = CreateFrame("Frame", "Sintezza_LootEventFrame")
local registeredEvents = {}

local buildInterface = type(GetBuildInfo) == "function" and select(4, GetBuildInfo()) or 0
ns.IsForever = (WOW_PROJECT_ID ~= nil and ((WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT) or WOW_PROJECT_ID == 18))
    or (buildInterface >= 16000 and buildInterface < 17000)

local rollWonEvent = "LOOT_ITEM_ROLL_WON"
local suppressedRollAlert
local winNotifications = {
    SINTEZZA = { sintezza = true, blizzard = false },
    BLIZZARD = { sintezza = false, blizzard = true },
    BOTH = { sintezza = true, blizzard = true },
    OFF = { sintezza = false, blizzard = false },
}

function ns:ShowsSintezzaWin()
    return winNotifications[self.db.winNotification].sintezza
end

function ns:GetAutoCloseDelay()
    if self.db.autoCloseEnabled then return self.db.autoCloseDelay end
end

function ns:ApplyBlizzardWinToastSetting()
    if not self.IsForever or InCombatLockdown() then return end

    local alert = AlertFrame
    if not alert or alert:IsForbidden() then return end

    if not winNotifications[self.db.winNotification].blizzard then
        if alert:IsEventRegistered(rollWonEvent) then
            alert:UnregisterEvent(rollWonEvent)
            suppressedRollAlert = alert
        end
    elseif suppressedRollAlert == alert then
        alert:RegisterEvent(rollWonEvent)
        suppressedRollAlert = nil
    end
end

-- Cross-client API compatibility wrappers (WoW Forever 1.60.1 / 12.x vs Classic Era 1.15.x / MoP 5.5.x)
function ns.IsSecretValue(val)
    return type(issecretvalue) == "function" and issecretvalue(val) or false
end

function ns.GetItemInfo(itemInfo)
    if not itemInfo then return nil end
    local fn = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if type(fn) == "function" then
        return fn(itemInfo)
    end
    return nil
end

local FALLBACK_QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 1.00, 1.00, 1.00 },
    [2] = { 0.12, 1.00, 0.00 },
    [3] = { 0.00, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 1.00, 0.50, 0.00 },
}

function ns.GetItemQualityColor(quality)
    local q = tonumber(quality) or 2
    local fn = (C_Item and C_Item.GetItemQualityColor) or _G.GetItemQualityColor
    if type(fn) == "function" then
        local r, g, b, hex = fn(q)
        if r and g and b then
            return r, g, b, hex
        end
    end
    if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
        local c = ITEM_QUALITY_COLORS[q]
        return c.r or 1, c.g or 1, c.b or 1, c.hex
    end
    local fb = FALLBACK_QUALITY_COLORS[q] or FALLBACK_QUALITY_COLORS[2]
    return fb[1], fb[2], fb[3]
end

function ns.SendWhisper(targetName)
    if not targetName or targetName == "" then return end
    if ChatFrameUtil and type(ChatFrameUtil.SendTell) == "function" then
        ChatFrameUtil.SendTell(targetName)
    elseif type(ChatFrame_SendTell) == "function" then
        ChatFrame_SendTell(targetName)
    elseif type(ChatFrame_OpenChat) == "function" then
        ChatFrame_OpenChat("/w " .. targetName .. " ")
    end
end

function ns:Print(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff82d9c8[Sintezza Loot]|r " .. tostring(msg))
    else
        print("|cff82d9c8[Sintezza Loot]|r " .. tostring(msg))
    end
end

function ns:InitDB()
    if type(Sintezza_LootDB) ~= "table" then
        Sintezza_LootDB = {}
    end
    for k, v in pairs(DEFAULT_SETTINGS) do
        if Sintezza_LootDB[k] == nil then
            if type(v) == "table" then
                Sintezza_LootDB[k] = CopyTable(v)
            else
                Sintezza_LootDB[k] = v
            end
        end
    end
    ns.db = Sintezza_LootDB
    local db = ns.db
    if not winNotifications[db.winNotification] then
        local custom = db.animateWin ~= false
        local blizzard = db.hideBlizzardWinToast == false
        if custom then db.winNotification = blizzard and "BOTH" or "SINTEZZA"
        else db.winNotification = blizzard and "BLIZZARD" or "OFF" end
    end
    db.animateWin, db.hideBlizzardWinToast = nil, nil
    local delay = tonumber(db.autoCloseDelay) or ns.DEFAULT_AUTO_CLOSE_DELAY
    if type(db.autoCloseEnabled) ~= "boolean" then
        db.autoCloseEnabled = delay > 0
        if not db.autoCloseEnabled then delay = ns.DEFAULT_AUTO_CLOSE_DELAY end
    end
    db.autoCloseDelay = math.min(15, math.max(0, delay))
    if type(ns.db.rollHistory) ~= "table" then ns.db.rollHistory = {} end
    if type(ns.db.minimap) ~= "table" then ns.db.minimap = { minimapPos = 165 } end
end

local competingTracker = "ClearLoot"
local warnedAboutConflict

function ns:GetCompetingTracker()
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not isLoaded then return end
    local loaded, finished = isLoaded(competingTracker)
    if finished == true or (finished == nil and loaded == true) then
        return "Clear Loot"
    end
end

local function WarnAboutCompetingTracker()
    if warnedAboutConflict then return end
    local competitor = ns:GetCompetingTracker()
    if competitor then
        warnedAboutConflict = true
        ns:Print(L.TRACKER_CONFLICT:format(competitor))
    end
end

function ns:RegisterEvent(event, handler)
    if not registeredEvents[event] then
        registeredEvents[event] = {}
        pcall(function()
            eventFrame:RegisterEvent(event)
        end)
    end
    table.insert(registeredEvents[event], handler)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = registeredEvents[event]
    if handlers then
        for i = 1, #handlers do
            handlers[i](event, ...)
        end
    end
end)

local function TrimString(s)
    if type(s) ~= "string" then return "" end
    if type(strtrim) == "function" then
        return strtrim(s)
    end
    return s:match("^%s*(.-)%s*$") or ""
end

local function ExecuteSlashCommand(msg)
    if not ns.db then
        ns:InitDB()
    end
    local cmd = TrimString(msg):lower()

    if cmd == "test" or cmd == "sim" then
        if ns.Simulator then
            ns.Simulator:StartSingleTest()
        end
    elseif cmd == "testmulti" or cmd == "multi" then
        if ns.Simulator then
            ns.Simulator:StartMultiTest()
        end
    elseif cmd == "testraid" or cmd == "raid" then
        if ns.Simulator then
            ns.Simulator:StartRaidTest(40)
        end
    elseif cmd == "stop" or cmd == "clear" then
        if ns.Simulator then
            ns.Simulator:StopTests()
        end
    elseif cmd == "show" then
        if ns.RollTrackerFrame then
            ns.RollTrackerFrame:ForceShowCurrent()
        end
    elseif cmd == "history" then
        ns.History:Toggle()
    elseif cmd == "newrun" then
        if ns.History:StartNewRun() then ns:Print(L.MSG_NEW_RUN) end
    elseif cmd == "move" then
        if ns.RollTrackerFrame and ns.RollTrackerFrame.ToggleMoveMode then
            ns.RollTrackerFrame:ToggleMoveMode()
        end
    elseif cmd == "unlock" or cmd == "lock" then
        ns.TrackerAppearance:Set("locked", cmd == "lock")
    elseif cmd == "reset" then
        ns.Settings:ResetRollPosition()
        ns:Print(L.MSG_POS_RESET)
    elseif cmd == "" or cmd == "config" or cmd == "options" or cmd == "settings" then
        if ns.Settings then
            ns.Settings:ToggleSettings()
        end
    elseif cmd == "help" then
        ns:Print(L.SLASH_HELP_HEADER)
        ns:Print(L.SLASH_HELP_TEST)
        ns:Print(L.SLASH_HELP_TESTMULTI)
        ns:Print(L.SLASH_HELP_TESTRAID)
        ns:Print(L.SLASH_HELP_STOP)
        ns:Print(L.SLASH_HELP_SHOW)
        ns:Print(L.SLASH_HELP_HISTORY)
        ns:Print(L.SLASH_HELP_NEWRUN)
        ns:Print(L.SLASH_HELP_MOVE)
        ns:Print(L.SLASH_HELP_LOCK)
        ns:Print(L.SLASH_HELP_CONFIG)
    else
        ns:Print(L.SLASH_HELP_HEADER)
    end
end

local function HandleSlashCommand(msg)
    local ok, err = pcall(ExecuteSlashCommand, msg)
    if not ok then
        ns:Print("|cffff4444" .. L.COMMAND_ERROR .. "|r " .. tostring(err))
    end
end

SLASH_SINTEZZA_LOOT1 = "/sloot"
SLASH_SINTEZZA_LOOT2 = "/sintezza_loot"
SLASH_SINTEZZA_LOOT3 = "/standaloneloot"
SlashCmdList["SINTEZZA_LOOT"] = HandleSlashCommand

ns:RegisterEvent("ADDON_LOADED", function(_, loadedName)
    if loadedName == competingTracker then
        WarnAboutCompetingTracker()
    end
    if loadedName ~= addonName then
        return
    end

    ns:InitDB()
    WarnAboutCompetingTracker()

    local modules = {
        { name = "RosterInspector", mod = ns.RosterInspector },
        { name = "History",        mod = ns.History },
        { name = "DataTracker",     mod = ns.DataTracker },
        { name = "RollTrackerFrame",mod = ns.RollTrackerFrame },
        { name = "MultiItemManager",mod = ns.MultiItemManager },
        { name = "Settings",        mod = ns.Settings },
    }

    for _, entry in ipairs(modules) do
        if entry.mod and entry.mod.Init then
            local ok, err = pcall(entry.mod.Init, entry.mod)
            if not ok then
                ns:Print(L.INIT_ERROR:format(entry.name, tostring(err)))
            end
        end
    end
    ns.Launcher:RegisterMinimap(L.ADDON_TITLE, ns.ICON, ns.db.minimap, function() ns.History:Toggle() end)
end)

local function ApplyBlizzardWinToastSetting()
    if ns.db then ns:ApplyBlizzardWinToastSetting() end
end

if ns.IsForever then
    ns:RegisterEvent("PLAYER_LOGIN", ApplyBlizzardWinToastSetting)
    ns:RegisterEvent("PLAYER_REGEN_ENABLED", ApplyBlizzardWinToastSetting)
end
