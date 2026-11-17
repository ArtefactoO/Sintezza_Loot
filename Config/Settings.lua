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
    panel:SetSize(720, 344)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    T:WindowSurface(panel)

    local header = W:WindowHeader(panel, {
        icon = ns.ICON,
        title = L.ADDON_TITLE,
        version = ns.VERSION,
    })
    panel.header = header
    AttachDrag(panel, header)
    panel.close = header.close
    local backToHistory = Button(header, L.HISTORY_BACK, 104, function() self:ReturnToHistory(true) end)
    backToHistory:SetPoint("RIGHT", header.close, "LEFT", -4, 0)
    panel:HookScript("OnHide", function()
        if self.fromHistory then self:ReturnToHistory() end
    end)

    local sidebar = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
    sidebar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(172)
    T:SidebarSurface(sidebar)

    local scroll, body, bar = W:ScrollFrame(panel)
    scroll:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 14, -14)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 14)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    scroll:HookScript("OnSizeChanged", function(_, width)
        body:SetWidth(math.max(1, width))
        scroll:RefreshRange()
    end)
    body:SetWidth(math.max(1, scroll:GetWidth()))

    local pages, buttons = {}, {}
    local selected
    local function SelectPage(key)
        if key == selected then return end
        if selected then
            pages[selected]:Hide()
            buttons[selected]:SetSelected(false)
        end
        selected = key
        local page = pages[key]
        page:Show()
        body:SetHeight(page:GetHeight())
        scroll:RefreshRange()
        scroll:SetVerticalScroll(0)
        buttons[key]:SetSelected(true)
    end

    local page, banded
    local navY = -8
    local function StartPage(key, title, heading)
        local button = W:NavButton(sidebar, title, key, SelectPage)
        button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, navY)
        button:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, navY)
        navY = navY - button:GetHeight()
        buttons[key] = button
        local hasHeading = heading and heading ~= title
        page = hasHeading and W:Section(body, heading, nil, "settings") or CreateFrame("Frame", nil, body)
        page.settingsTop = hasHeading and -(page.headerHeight + 4) or 0
        page.settingsInset = hasHeading and W.CONTROL_INSET or 0
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
                row:SetPoint("TOPRIGHT", card, "TOPRIGHT", -inset, y)
                y = y - row:GetHeight() - row.settingsGap
            end
        end
        card:SetHeight(-y + 10)
        if selected and pages[selected] == card then
            body:SetHeight(card:GetHeight())
            scroll:RefreshRange()
        end
    end

    local function Place(row, gap, setting)
        if setting then
            if not banded then T:RowBand(row) end
            banded = not banded
        end
        row.settingsGap = gap or 2
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

    local function Disclosure(title, build, refresh)
        local card, first = page, #page.rows + 2
        local expanded
        local action
        action = W:ActionRow(card, title, L.SETTINGS_SHOW, function()
            expanded = not expanded
            for index = first, action.lastRow do card.rows[index]:SetShown(expanded) end
            action.button:SetText(expanded and L.SETTINGS_HIDE or L.SETTINGS_SHOW)
            if refresh and expanded then refresh() end
            Relayout(card)
        end)
        Place(action, 4)
        build()
        action.lastRow = #card.rows
        for index = first, action.lastRow do card.rows[index]:Hide() end
        Relayout(card)
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
        row.button:SetWidth(245)
        Place(row, nil, true)
        return row
    end
StartPage("tracker", L.SETTINGS_TRACKER, L.SETTINGS_TRACKER_BEHAVIOR)
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
    Toggle(L.SETTINGS_NORMAL_TIMER, nil, "showRollTimer", RefreshTracker)

    Heading(L.SETTINGS_WIN_HEADING)
    Choice(L.SETTINGS_WIN_LABEL, nil, "winNotification", {
        SINTEZZA = "Sintezza", BLIZZARD = "Blizzard", BOTH = L.SETTINGS_WIN_BOTH, OFF = L.SETTINGS_WIN_OFF,
    }, { "SINTEZZA", "BLIZZARD", "BOTH", "OFF" }, function() ns:ApplyBlizzardWinToastSetting() end)

    Disclosure(L.SETTINGS_PARTICIPANTS, function()
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
    end)

    local conflict
    Disclosure(L.SETTINGS_CONFLICTS, function()
        conflict = Label("", T.muted, 50)
        conflict:SetWordWrap(true)
    end, function()
        local competitor = ns:GetCompetingTracker()
        conflict:SetText(competitor and L.SETTINGS_CONFLICT_LOADED:format(competitor) or L.SETTINGS_CONFLICT_NONE)
        Sintezza_Theme:Tint(conflict, "SetTextColor", competitor and T.warning or T.muted)
    end)

    StartPage("test", L.SETTINGS_PREVIEW, L.SETTINGS_TEST_HEADER)
    Choice(L.TEST_ITEMS, nil, "testItemCount", { [1] = "1", [2] = "2", [4] = "4" }, { 1, 2, 4 })
    Choice(L.TEST_PLAYERS, nil, "testGroupSize", { [5] = "5", [10] = "10", [20] = "20", [40] = "40" },
        { 5, 10, 20, 40 })
    Choice(L.TEST_ROLL_FLOW, L.TEST_ROLL_FLOW_HELP, "testScenario", {
        TIMEOUT = L.TEST_TIMEOUT, SELF = L.TEST_SELF_WIN, OTHER = L.TEST_OTHER_WIN, PASS = L.TEST_ALL_PASS,
    }, { "SELF", "TIMEOUT", "OTHER", "PASS" })
    self.testButton = Place(Button(page, L.TEST_START, 185, function()
        if self.testRunning then
            ns.Simulator:StopTests()
        else
            local ok, err = pcall(ns.Simulator.StartTest, ns.Simulator,
                ns.db.testItemCount, ns.db.testGroupSize, ns.db.testScenario)
            if not ok then ns:Print(L.SIMULATION_ERROR .. " · " .. tostring(err)) end
        end
    end), 4)

    StartPage("data", L.DATA_TITLE, L.HISTORY_TITLE)
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
    Place(Button(page, L.DATA_TRANSFER, 210, function()
        Sintezza_Theme.DataTransfer:Open(panel, ns.DataTransferSpec)
    end))
    Place(Button(page, L.DATA_MAINTENANCE, 210, function()
        Sintezza_Theme.DataTransfer:OpenMaintenance(panel, ns.DataTransferSpec)
    end))

    StartPage("window", L.SETTINGS_WINDOW_HEADER)
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
    Place(Button(page, L.SETTINGS_MOVE_BTN, 178, function() ns.RollTrackerFrame:ToggleMoveMode() end))

    SelectPage("tracker")
    ApplyPosition(panel)
    table.insert(UISpecialFrames, panel:GetName())
    self.panel = panel
    self.SelectPage = SelectPage
    ns.WindowAppearance:Bind(panel, {
        layout = function()
            ApplyPosition(panel)
            ns.MultiItemManager:UpdateAnchoring()
        end,
        resize = { minWidth = 720, minHeight = 314, maxWidth = 1300, maxHeight = 850 },
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

function SettingsModule:OpenDataFromHistory()
    if not self.panel then return end
    self:OpenFromHistory()
    self.SelectPage("data")
end

function SettingsModule:OpenFromHistory()
    if not self.panel then return end
    self.fromHistory = true
    ns.History.frame:Hide()
    self:OpenSettings()
end

function SettingsModule:ReturnToHistory(force)
    if not self.panel or (not force and not self.fromHistory) then return false end
    self.fromHistory = nil
    self.panel:Hide()
    ns.History:Open()
    return true
end

function SettingsModule:Hide()
    if self.panel then self.panel:Hide() end
end

function SettingsModule:ToggleSettings()
    local panel = self.panel
    if panel and panel:IsShown() then
        panel:Hide()
    else
        self:OpenSettings()
    end
end
