local _, ns = ...
local L, T = ns.L, ns.Theme
local W = Sintezza_Theme:CreateWidgets(T)

local SettingsModule = {}
ns.Settings = SettingsModule
ns.WindowAppearance = Sintezza_Theme:NewWindowPreferences(function() return ns.db end)
ns.TrackerAppearance = Sintezza_Theme:NewWindowPreferences(function() return ns.db end, function(db)
    return { scale = db.windowScale, opacity = db.windowOpacity }
end, "trackerAppearance")
if Sintezza_Theme.RegisterGlobalWindowPreferences then
    Sintezza_Theme:RegisterGlobalWindowPreferences("Sintezza Loot", ns.WindowAppearance)
    Sintezza_Theme:RegisterGlobalWindowPreferences("Sintezza Loot", ns.TrackerAppearance)
end

function ns.WindowAppearance:OnReset()
    ns.db.settingsPosition = nil
end

function ns.TrackerAppearance:OnReset()
    SettingsModule:ResetRollPosition()
    return true
end

function ns.TrackerAppearance:OnChanged(key)
    if key == "locked" and self:Get("locked") then ns.RollTrackerFrame:SetMoveMode(false, false) end
end

local function Button(parent, text, width, click)
    local button = W:Button(parent, text, click)
    button:SetSize(width, 26)
    return button
end

local function GetPosition()
    local pos = ns.db.settingsPosition
    return type(pos) == "table" and tonumber(pos.x) or 0, type(pos) == "table" and tonumber(pos.y) or 0
end

local function PlaceWindow(panel, x, y, scale)
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", x / scale, y / scale)
end

local function GetWindowBounds(panel, scale)
    return math.max(0, (UIParent:GetWidth() - panel:GetWidth() * scale) / 2 - 8),
        math.max(0, (UIParent:GetHeight() - panel:GetHeight() * scale) / 2 - 8)
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function ApplyPosition(panel)
    local x, y = GetPosition()
    local scale = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local maxX, maxY = GetWindowBounds(panel, scale)
    PlaceWindow(panel, Clamp(x, -maxX, maxX), Clamp(y, -maxY, maxY), scale)
end

local function AttachDrag(panel, header)
    panel:SetMovable(true)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if not ns.WindowAppearance:CanMove() then return end
        panel.dragging = true
        panel:Raise()
        panel:StartMoving()
    end)
    local function StopDrag()
        if not panel.dragging then return end
        panel.dragging = nil
        panel:StopMovingOrSizing()
        local x, y = panel:GetCenter()
        local cx, cy = UIParent:GetCenter()
        local scale = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if x and y and cx and cy then ns.db.settingsPosition = { x = x * scale - cx, y = y * scale - cy } end
        ApplyPosition(panel)
    end
    header:SetScript("OnDragStop", StopDrag)
    panel:HookScript("OnHide", StopDrag)
end

function SettingsModule:Init()
    local panel = CreateFrame("Frame", "Sintezza_LootSettingsPanel", UIParent, "BackdropTemplate")
    panel:Hide()
    panel:SetSize(650, 544)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    T:WindowSurface(panel)

    local header = W:WindowHeader(panel, {
        icon = ns.ICON,
        title = L.SETTINGS_TITLE,
        version = ns.VERSION,
    })
    AttachDrag(panel, header)

    local keys = { "tracker", "test", "data", "window" }
    local labels = { L.SETTINGS_TRACKER, L.SETTINGS_PREVIEW, L.DATA_TITLE, L.SETTINGS_WINDOW_HEADER }
    local pages, selected, tabs = {}
    local scroll, body, bar = W:ScrollFrame(panel)
    local function SelectPage(key)
        if key == selected or not pages[key] then return end
        if selected then pages[selected]:Hide() end
        selected = key
        local page = pages[key]
        page:Show()
        body:SetHeight(page:GetHeight())
        scroll:RefreshRange()
        scroll:SetVerticalScroll(0)
        tabs:Refresh()
    end
    tabs = W:Segmented(panel, labels, keys, function() return selected end, SelectPage, true)
    tabs:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 12, -4)
    tabs:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -12, -4)
    scroll:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 12)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    scroll:HookScript("OnSizeChanged", function(_, width)
        body:SetWidth(math.max(1, width))
        scroll:RefreshRange()
    end)
    body:SetWidth(math.max(1, scroll:GetWidth()))

    local page, banded
    local function StartPage(key, heading)
        page = heading and W:Section(body, heading, nil, "settings") or CreateFrame("Frame", nil, body)
        page.settingsTop = heading and -(page.headerHeight + 4) or 0
        page.settingsInset = heading and W.CONTROL_INSET or 0
        page:SetPoint("TOPLEFT")
        page:SetPoint("TOPRIGHT")
        page:Hide()
        pages[key] = page
        page.rows, banded = {}, false
    end

    local function Relayout(card)
        local y, inset = card.settingsTop, card.settingsInset
        for _, row in ipairs(card.rows) do
            if row:IsShown() then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", card, "TOPLEFT", inset, y)
                if not row.settingsCompact then
                    row:SetPoint("TOPRIGHT", card, "TOPRIGHT", -inset, y)
                end
                y = y - row:GetHeight() - row.settingsGap
            end
        end
        card:SetHeight(-y + 10)
        if selected and pages[selected] == card then
            body:SetHeight(card:GetHeight())
            scroll:RefreshRange()
        end
    end

    local function Place(row, gap, setting, compact)
        if setting then
            if not banded then T:RowBand(row) end
            banded = not banded
        end
        row.settingsGap = gap or 2
        row.settingsCompact = compact
        page.rows[#page.rows + 1] = row
        Relayout(page)
        return row
    end

    local function Label(text, color, height)
        local label = W:Label(page, text, 12, color or T.muted)
        label:SetHeight(height or 25)
        label:SetJustifyH("LEFT")
        return Place(label, 4)
    end

    local function Heading(text)
        return Label(text, T.text, 28)
    end

    local function Action(text, width, click, gap)
        return Place(Button(page, text, width, click), gap or 4, false, true)
    end

    local function RefreshTracker() ns.RollTrackerFrame:Refresh() end
    local function BuildToggle(parent, label, description, key, changed, getter)
        local get = getter or function() return ns.db[key] == true end
        local function Set(value)
            if not getter then ns.db[key] = value end
            if changed then changed(value) end
        end
        local row = W:Toggle(parent, label, get, Set)
        if W.Help then W:Help(row, description) end
        return row
    end
    local function Toggle(...)
        return Place(BuildToggle(page, ...), nil, true)
    end
    local function BuildChoice(parent, label, description, key, choices, order, changed)
        local function Get() return ns.db[key] end
        local function Set(value)
            ns.db[key] = value
            if changed then changed() end
        end
        local preferred = {}
        for i, value in ipairs(order) do preferred[value] = i end
        local row = W:ChoiceRow(parent, label, choices, Get, Set, preferred)
        row:HookScript("OnShow", function(self) self:Refresh() end)
        if W.Help then W:Help(row, description) end
        return row
    end
    local function Choice(...)
        local row = BuildChoice(page, ...)
        Place(row, nil, true)
        return row
    end
    StartPage("tracker", L.SETTINGS_TRACKER_BEHAVIOR)
    local trackerPage = page
    local recordingNotice
    local function RefreshTrackerOptions()
        recordingNotice:SetShown(not ns.db.enabled)
        Relayout(trackerPage)
    end
    Toggle(L.SETTINGS_SHOW_TRACKER, nil, "enabled", function()
        RefreshTracker()
        RefreshTrackerOptions()
    end)
    recordingNotice = Label(L.SETTINGS_HISTORY_RECORDS, T.accent)
    RefreshTrackerOptions()
    Toggle(L.SETTINGS_AUTO_OPEN, nil, "autoOpen")
    Toggle(L.SETTINGS_AUTO_SWITCH, L.SETTINGS_AUTO_SWITCH_DESC, "autoSwitchOnHover")
    local delay
    Toggle(L.SETTINGS_CLOSE_ENABLED, nil, "autoCloseEnabled", function(value)
        delay:SetShown(value)
        Relayout(trackerPage)
        ns.DataTracker:TriggerAutoCloseForCompletedRolls()
    end)
    delay = Place(W:SliderRow(page, L.SETTINGS_CLOSE_DELAY, 0, 15, 1,
        function() return ns.db.autoCloseDelay end,
        function(value)
            ns.db.autoCloseDelay = value
            ns.DataTracker:TriggerAutoCloseForCompletedRolls()
        end, L.SETTINGS_SECONDS), nil, true)
    delay:SetShown(ns.db.autoCloseEnabled)
    Relayout(page)
    Toggle(L.SETTINGS_NORMAL_TIMER, nil, "showRollTimer", RefreshTracker).settingsGap = 8

    local winPreview
    Choice(L.SETTINGS_WIN_HEADING, nil, "winNotification", {
        SINTEZZA = "Sintezza", BLIZZARD = "Blizzard", BOTH = L.SETTINGS_WIN_BOTH, OFF = L.SETTINGS_WIN_OFF,
    }, { "SINTEZZA", "BLIZZARD", "BOTH", "OFF" }, function()
        ns:ApplyBlizzardWinToastSetting()
        winPreview:SetEnabled(ns.db.winNotification ~= "OFF")
    end)
    winPreview = Action(L.SETTINGS_PREVIEW_WIN, 144, function() ns.Simulator:PreviewWin() end, 8)
    winPreview:SetEnabled(ns.db.winNotification ~= "OFF")

    Heading(L.SETTINGS_PARTICIPANTS)
    Choice(L.SETTINGS_CHOICE_DISPLAY, nil, "choiceDisplay", {
        ICONS = L.SETTINGS_CHOICE_ICONS, TEXT = L.SETTINGS_CHOICE_TEXT, BOTH = L.SETTINGS_CHOICE_BOTH,
    }, { "BOTH", "ICONS", "TEXT" }, RefreshTracker)
    Toggle(L.SETTINGS_SHOW_PASS, nil, "hidePassed", function(value)
        ns.db.hidePassed = not value
        RefreshTracker()
    end, function() return not ns.db.hidePassed end)
    Toggle(L.SETTINGS_SHOW_PENDING, nil, "hidePending", function(value)
        ns.db.hidePending = not value
        RefreshTracker()
    end, function() return not ns.db.hidePending end)
    Toggle(L.SETTINGS_SHOW_ROLE, nil, "showRoleIcons", RefreshTracker)

    Heading(L.SETTINGS_CONFLICTS)
    local conflict = Label("", T.muted, 36)
    conflict:SetWordWrap(true)
    local function RefreshConflict()
        local competitor = ns:GetCompetingTracker()
        conflict:SetText(competitor and L.SETTINGS_CONFLICT_LOADED:format(competitor) or L.SETTINGS_CONFLICT_NONE)
        Sintezza_Theme:Tint(conflict, "SetTextColor", competitor and T.warning or T.muted)
    end
    trackerPage:HookScript("OnShow", RefreshConflict)

    StartPage("test", L.SETTINGS_TEST_HEADER)
    Choice(L.TEST_ITEMS, nil, "testItemCount", { [1] = "1", [2] = "2", [4] = "4" }, { 1, 2, 4 })
    Choice(L.TEST_PLAYERS, nil, "testGroupSize", { [5] = "5", [10] = "10", [20] = "20", [40] = "40" },
        { 5, 10, 20, 40 })
    Choice(L.TEST_ROLL_FLOW, L.TEST_ROLL_FLOW_HELP, "testScenario", {
        TIMEOUT = L.TEST_TIMEOUT, SELF = L.TEST_SELF_WIN, OTHER = L.TEST_OTHER_WIN, PASS = L.TEST_ALL_PASS,
    }, { "SELF", "TIMEOUT", "OTHER", "PASS" })
    self.testButton = Action(L.TEST_START, 144, function()
        if self.testRunning then
            ns.Simulator:StopTests()
        else
            local ok, err = pcall(ns.Simulator.StartTest, ns.Simulator,
                ns.db.testItemCount, ns.db.testGroupSize, ns.db.testScenario)
            if not ok then ns:Print(L.SIMULATION_ERROR .. " · " .. tostring(err)) end
        end
    end)

    StartPage("data", L.HISTORY_TITLE)
    local dataPage = page
    local stats = {}
    for index, label in ipairs({ L.HISTORY_RUNS, L.DATA_ROLLS, L.HISTORY_PERSONAL }) do
        stats[index] = Label(label, T.text)
    end
    self.RefreshData = function()
        local counts = ns.History:GetDataCounts()
        for index, label in ipairs({ L.HISTORY_RUNS, L.DATA_ROLLS, L.HISTORY_PERSONAL }) do
            stats[index]:SetText(label .. "  ·  " .. counts[index])
        end
    end
    dataPage:HookScript("OnShow", self.RefreshData)
    Action(L.DATA_TRANSFER, 166, function()
        Sintezza_Theme.DataTransfer:Open(panel, ns.DataTransferSpec)
    end)
    Action(L.DATA_MAINTENANCE, 166, function()
        Sintezza_Theme.DataTransfer:OpenMaintenance(panel, ns.DataTransferSpec)
    end)

    StartPage("window")
    if ns.IsForever and T.SkinLootRollPopup then
        Toggle(L.SETTINGS_SKIN_GROUP_LOOT, L.SETTINGS_SKIN_GROUP_LOOT_HELP, "skinGroupLoot")
    end
    Place(Sintezza_Theme:CreateWindowOptions(page, T, {
        windows = {
            { label = L.SETTINGS_HISTORY_WINDOWS, prefs = ns.WindowAppearance },
            { label = L.SETTINGS_ROLL_HEADER, prefs = ns.TrackerAppearance },
        },
        getMinimap = function() return not ns.db.minimap.hide end,
        setMinimap = function(value)
            ns.db.minimap.hide = not value
            ns.Launcher:RefreshMinimap(ns.db.minimap)
        end,
    }))
    self.anchorRow = Choice(L.SETTINGS_ANCHOR_SIDE, nil, "anchorSide", {
        RIGHT = L.SETTINGS_ANCHOR_RIGHT, LEFT = L.SETTINGS_ANCHOR_LEFT, FREE = L.SETTINGS_ANCHOR_FREE,
    }, { "RIGHT", "LEFT", "FREE" }, function() ns.MultiItemManager:UpdateAnchoring() end)
    Action(L.SETTINGS_MOVE_BTN, 158, function() ns.RollTrackerFrame:ToggleMoveMode() end)

    SelectPage("tracker")
    ApplyPosition(panel)
    table.insert(UISpecialFrames, panel:GetName())
    self.panel = panel
    ns.WindowAppearance:Bind(panel, {
        layout = function()
            ApplyPosition(panel)
            ns.MultiItemManager:UpdateAnchoring()
        end,
        resize = { minWidth = 625, minHeight = 460, maxWidth = 1300, maxHeight = 850 },
    })
    ns.Launcher:RegisterSettings(L.ADDON_TITLE, function() self:OpenSettings() end)
end

function SettingsModule:UpdateTestActions(active)
    self.testRunning = active
    if self.testButton then self.testButton:SetText(active and L.TEST_STOP or L.TEST_START) end
end

function SettingsModule:ResetRollPosition()
    ns.db.freePosition = nil
    ns.db.anchorSide = "RIGHT"
    ns.MultiItemManager:UpdateAnchoring()
    if self.anchorRow then self.anchorRow:Refresh() end
end

function SettingsModule:OnRollPositionChanged()
    if self.anchorRow then self.anchorRow:Refresh() end
end

function SettingsModule:OpenSettings()
    local panel = self.panel
    if not panel then return end
    ns.WindowAppearance:ApplyTo(panel)
    self:OnRollPositionChanged()
    panel:Show()
    panel:Raise()
end

function SettingsModule:ToggleSettings()
    local panel = self.panel
    if panel and panel:IsShown() then
        panel:Hide()
    else
        self:OpenSettings()
    end
end
