local addonName, ns = ...
local T = ns.Theme
local widgets = Sintezza_Theme:CreateWidgets(T)
local L = ns.L
local DataTracker = ns.DataTracker

local RollTrackerFrame = {}
ns.RollTrackerFrame = RollTrackerFrame

local WINDOW_WIDTH_ICONS = 324
local WINDOW_WIDTH_TEXT  = 360
local WINDOW_WIDTH_BOTH  = 378
local ITEM_HEADER_HEIGHT = 34
local HEADER_HEIGHT = ITEM_HEADER_HEIGHT + 26
local FOOTER_HEIGHT = 26
local ROW_HEIGHT = 20
local MIN_VISIBLE_ROWS = 5
local MAX_VISIBLE_ROWS = 10
local MAX_TABS = 6

local ROLL_ICONS = DataTracker.ROLL_ICONS

function RollTrackerFrame:GetChoiceDisplayMode()
    local mode = ns.db and ns.db.choiceDisplay or "ICONS"
    if mode ~= "ICONS" and mode ~= "TEXT" and mode ~= "BOTH" then
        mode = "ICONS"
    end
    return mode
end

function RollTrackerFrame:GetWindowWidth()
    local mode = self:GetChoiceDisplayMode()
    if mode == "TEXT" then
        return WINDOW_WIDTH_TEXT
    elseif mode == "BOTH" then
        return WINDOW_WIDTH_BOTH
    end
    return WINDOW_WIDTH_ICONS
end

local ROLL_COLORS = {
    [DataTracker.ROLL_TYPE_NEED]       = { r = 0.20, g = 1.00, b = 0.20 },
    [DataTracker.ROLL_TYPE_GREED]      = { r = 0.35, g = 0.80, b = 1.00 },
    [DataTracker.ROLL_TYPE_DISENCHANT] = { r = 0.75, g = 0.45, b = 1.00 },
    [DataTracker.ROLL_TYPE_PASS]       = { r = 0.85, g = 0.25, b = 0.25 },
    [DataTracker.ROLL_TYPE_PENDING]    = { r = 0.65, g = 0.65, b = 0.65 },
}

local ROLE_TEX_COORDS = {
    TANK    = { 0, 19/64, 22/64, 41/64 },
    HEALER  = { 20/64, 39/64, 1/64, 20/64 },
    DAMAGER = { 20/64, 39/64, 22/64, 41/64 },
}

local dropdownFrame

local function ShowPlayerContextMenu(playerData, anchorFrame)
    if not playerData or not playerData.name then return end
    local targetName = playerData.fullName or playerData.name
    local unit, unitMenuType = ns.RosterInspector:FindUnitByName(targetName)

    -- 1. If the player is in our party/raid (or is ourselves), open the exact native UnitPopup menu
    if unit and unitMenuType then
        if type(UnitPopup_OpenMenu) == "function" then
            local contextData = {
                unit = unit,
                name = UnitName(unit) or playerData.name,
            }
            local ok = pcall(UnitPopup_OpenMenu, unitMenuType, contextData)
            if ok then return end
        end
    end

    -- 2. Otherwise (or for simulated players / players who left the group), open the full native chat/player menu
    -- Passing "PARTY" and DEFAULT_CHAT_FRAME ensures Blizzard populates Whisper, Invite, Ignore, Target, Copy Name
    if type(UnitPopup_OpenMenu) == "function" then
        local contextData = {
            name = targetName,
            playerLocation = PlayerLocation and PlayerLocation:CreateFromName(targetName) or nil,
            chatType = "PARTY",
            chatTarget = targetName,
            chatFrame = DEFAULT_CHAT_FRAME,
            lineID = 0,
        }
        local ok = pcall(UnitPopup_OpenMenu, "FRIEND", contextData)
        if ok then return end
    end

    if type(FriendsFrame_ShowDropdown) == "function" then
        local ok = pcall(FriendsFrame_ShowDropdown, targetName, 1, 0, "PARTY", DEFAULT_CHAT_FRAME)
        if ok then return end
    end

    -- 3. Modern MenuUtil Context Menu (WoW Forever 1.60.1 / Mainline UI)
    if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
        local ok = pcall(T.OpenMenu, T, anchorFrame, function(_, rootDescription)
            rootDescription:CreateTitle(ns.RosterInspector:ColorizeName(playerData.name, playerData.class))
            rootDescription:CreateButton(L.MENU_WHISPER, function()
                ns.SendWhisper(targetName)
            end)
            if not InCombatLockdown() and type(InspectUnit) == "function" then
                rootDescription:CreateButton(L.MENU_INSPECT, function()
                    InspectUnit(playerData.name)
                end)
            end
            rootDescription:CreateButton(L.MENU_INVITE, function()
                if C_PartyInfo and C_PartyInfo.InviteUnit then
                    C_PartyInfo.InviteUnit(targetName)
                elseif InviteUnit then
                    InviteUnit(targetName)
                end
            end)
            rootDescription:CreateButton(L.MENU_CANCEL, function() end)
        end)
        if ok then return end
    end

    -- 4. Legacy UIDropDownMenuTemplate fallback (Whisper, Inspect, Invite, Cancel)
    if type(UIDropDownMenu_Initialize) ~= "function" or type(ToggleDropDownMenu) ~= "function" then
        return
    end
    if DoesTemplateExist and not DoesTemplateExist("UIDropDownMenuTemplate") then
        return
    end

    if not dropdownFrame then
        dropdownFrame = CreateFrame("Frame", "Sintezza_LootPlayerDropDown", UIParent, "UIDropDownMenuTemplate")
    end

    UIDropDownMenu_Initialize(dropdownFrame, function(_, level)
        if level ~= 1 then return end

        local titleInfo = UIDropDownMenu_CreateInfo()
        titleInfo.text = ns.RosterInspector:ColorizeName(playerData.name, playerData.class)
        titleInfo.isTitle = true
        titleInfo.notCheckable = true
        UIDropDownMenu_AddButton(titleInfo, level)

        -- Whisper / Send Message
        local whisperInfo = UIDropDownMenu_CreateInfo()
        whisperInfo.text = L.MENU_WHISPER
        whisperInfo.notCheckable = true
        whisperInfo.func = function()
            ns.SendWhisper(targetName)
        end
        UIDropDownMenu_AddButton(whisperInfo, level)

        -- Inspect (if out of combat and in range)
        local inspectInfo = UIDropDownMenu_CreateInfo()
        inspectInfo.text = L.MENU_INSPECT
        inspectInfo.notCheckable = true
        inspectInfo.disabled = InCombatLockdown()
        inspectInfo.func = function()
            if InspectUnit then
                InspectUnit(playerData.name)
            end
        end
        UIDropDownMenu_AddButton(inspectInfo, level)

        -- Invite to Group (useful if testing solo or player left party)
        local inviteInfo = UIDropDownMenu_CreateInfo()
        inviteInfo.text = L.MENU_INVITE
        inviteInfo.notCheckable = true
        inviteInfo.func = function()
            if C_PartyInfo and C_PartyInfo.InviteUnit then
                C_PartyInfo.InviteUnit(targetName)
            elseif InviteUnit then
                InviteUnit(targetName)
            end
        end
        UIDropDownMenu_AddButton(inviteInfo, level)

        -- Cancel
        local cancelInfo = UIDropDownMenu_CreateInfo()
        cancelInfo.text = L.MENU_CANCEL
        cancelInfo.notCheckable = true
        UIDropDownMenu_AddButton(cancelInfo, level)
    end, "MENU")

    ToggleDropDownMenu(1, nil, dropdownFrame, "cursor", 0, 0)
end

local function CreateItemTab(parent, index)
    local tab = CreateFrame("Button", "Sintezza_LootItemTab" .. index, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    tab:SetSize(30, 30)

    T:SkinTab(tab)

    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tab.icon = icon
    tab.iconBorder = T:FrameIcon(tab, icon)

    local badge = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge:SetPoint("BOTTOMRIGHT", -2, 2)
    T:Font(badge, 9, "OUTLINE", T.text)
    tab.badge = badge

    tab:SetScript("OnClick", function(self)
        if self.rollID then
            DataTracker:SetCurrentRollID(self.rollID, true)
        end
    end)

    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemLink then
            GameTooltip:SetHyperlink(self.itemLink)
        elseif self.itemName then
            GameTooltip:SetText(self.itemName, 1, 1, 1)
        end
        GameTooltip:Show()
    end)

    tab:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    tab:Hide()
    return tab
end

local function CreatePlayerRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(WINDOW_WIDTH_ICONS - 24, ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.rowIndex = index

    -- Alternating subtle stripe background (or leader gold highlight)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    if index % 2 == 1 then
        bg:SetColorTexture(1, 1, 1, 0.04)
    else
        bg:SetColorTexture(0, 0, 0, 0.15)
    end
    row.bg = bg

    -- Hover highlight
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    Sintezza_Theme:Tint(hl, "SetColorTexture", T.accent, .12)

    -- 1. Rank Number ("1.")
    local rankText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rankText:SetPoint("LEFT", 4, 0)
    rankText:SetWidth(18)
    rankText:SetJustifyH("LEFT")
    T:Font(rankText, 11, "", T.muted)
    row.rankText = rankText

    -- 2. Class Icon
    local classIcon = row:CreateTexture(nil, "ARTWORK")
    classIcon:SetSize(15, 15)
    classIcon:SetPoint("LEFT", rankText, "RIGHT", 2, 0)
    classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    row.classIcon = classIcon

    -- 3. Player Name (Class Colored)
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", classIcon, "RIGHT", 5, 0)
    nameText:SetWidth(156)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    T:Font(nameText, 12, "", T.text)
    row.nameText = nameText

    -- 4. Role Icon (Tank / Healer / DPS)
    local roleIcon = row:CreateTexture(nil, "ARTWORK")
    roleIcon:SetSize(14, 14)
    roleIcon:SetPoint("LEFT", nameText, "RIGHT", 2, 0)
    roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    row.roleIcon = roleIcon

    -- 5. Roll Choice Icon (Dice / Coin / DE / Pass)
    local choiceIcon = row:CreateTexture(nil, "ARTWORK")
    choiceIcon:SetSize(16, 16)
    choiceIcon:SetPoint("LEFT", row, "LEFT", 235, 0)
    row.choiceIcon = choiceIcon

    -- 6. Roll Choice Text ("Need", "Greed", "Pass")
    local choiceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    choiceText:SetPoint("LEFT", choiceIcon, "RIGHT", 4, 0)
    choiceText:SetWidth(76)
    choiceText:SetJustifyH("LEFT")
    choiceText:SetWordWrap(false)
    T:Font(choiceText, 11, "", T.muted)
    row.choiceText = choiceText

    -- 7. Roll Score ("94")
    local scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scoreText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    scoreText:SetWidth(26)
    scoreText:SetJustifyH("RIGHT")
    T:Font(scoreText, 12, "", T.text)
    row.scoreText = scoreText

    row:SetScript("OnClick", function(self, button)
        if not self.playerData then return end
        if button == "RightButton" then
            ShowPlayerContextMenu(self.playerData, self)
        elseif button == "LeftButton" and IsShiftKeyDown() then
            local target = self.playerData.fullName or self.playerData.name
            ns.SendWhisper(target)
        end
    end)

    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta)
        RollTrackerFrame:OnMouseWheel(delta)
    end)

    row:SetScript("OnEnter", function(self)
        if not self.playerData then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local colored = ns.RosterInspector:ColorizeName(self.playerData.name, self.playerData.class)
        GameTooltip:SetText(colored)
        GameTooltip:AddLine(L.TOOLTIP_PLAYER_CLICK, 0.75, 0.75, 0.75, true)
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row:Hide()
    return row
end

function RollTrackerFrame:OnMouseWheel(delta)
    local frame = self.frame
    if not frame then return end
    local maxOffset = frame.maxScrollOffset or 0
    if maxOffset <= 0 then return end

    local newOffset = (frame.scrollOffset or 0) - (delta > 0 and 1 or -1)
    if newOffset < 0 then newOffset = 0 end
    if newOffset > maxOffset then newOffset = maxOffset end

    if newOffset ~= frame.scrollOffset then
        frame.scrollOffset = newOffset
        if frame.scrollBar and frame.scrollBar:IsShown() then
            frame.scrollBar._updating = true
            frame.scrollBar:SetValue(newOffset)
            frame.scrollBar._updating = false
        end
        self:UpdatePlayerRows()
    end
end

function RollTrackerFrame:Init()
    local frame = CreateFrame("Frame", "Sintezza_LootTrackerFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(self:GetWindowWidth(), HEADER_HEIGHT + (MIN_VISIBLE_ROWS * ROW_HEIGHT) + FOOTER_HEIGHT)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    T:WindowSurface(frame)
    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(ITEM_HEADER_HEIGHT)
    T:HeaderSurface(header)

    frame.scrollOffset = 0
    frame.maxScrollOffset = 0
    frame:SetScript("OnMouseWheel", function(_, delta)
        RollTrackerFrame:OnMouseWheel(delta)
    end)

    frame:SetScript("OnDragStart", function(self)
        if not ns.TrackerAppearance:CanMove() then return end
        self.dragging = true
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        if not self.dragging then return end
        self.dragging = nil
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        if point then
            ns.db.anchorSide = "FREE"
            ns.db.freePosition = {
                point = point,
                relativePoint = relativePoint,
                x = x,
                y = y,
            }
            if ns.Settings then ns.Settings:OnRollPositionChanged() end
            ns.MultiItemManager:UpdateAnchoring()
        end
    end)

    -- Item Tabs above the top-left of the window (shown when 2+ items are active)
    frame.tabs = {}
    for i = 1, MAX_TABS do
        local tab = CreateItemTab(frame, i)
        if i == 1 then
            tab:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 6, -2)
        else
            tab:SetPoint("LEFT", frame.tabs[i - 1], "RIGHT", 4, 0)
        end
        frame.tabs[i] = tab
    end

    -- Close [X] button (dismisses current item only)
    local closeBtn = widgets:CloseButton(header, function()
        local session = DataTracker:GetCurrentRollSession()
        if session then
            DataTracker:DismissRoll(session.rollID)
        else
            frame:Hide()
        end
    end)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", header, "TOPRIGHT", -1, -1)
    closeBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.TOOLTIP_CLOSE_ITEM, 1, 0.82, 0)
        GameTooltip:Show()
    end)
    closeBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    frame.closeBtn = closeBtn

    -- Item Header Button (Icon + Item Link/Name, hoverable for item tooltip)
    local itemHeader = CreateFrame("Button", nil, header)
    itemHeader:SetPoint("TOPLEFT", header, "TOPLEFT", 9, -1)
    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(18, 18)
    logo:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
    logo:SetTexture(ns.ICON)
    itemHeader:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -28, 0)
    itemHeader:SetHeight(24)

    local itemIcon = itemHeader:CreateTexture(nil, "ARTWORK")
    itemIcon:SetSize(20, 20)
    itemIcon:SetPoint("LEFT", itemHeader, "LEFT", 0, 0)
    itemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.itemIcon = itemIcon
    frame.itemBorder = T:FrameIcon(itemHeader, itemIcon)

    local itemTitle = itemHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemTitle:SetPoint("LEFT", itemIcon, "RIGHT", 6, 0)
    itemTitle:SetPoint("RIGHT", itemHeader, "RIGHT", -2, 0)
    itemTitle:SetJustifyH("LEFT")
    itemTitle:SetWordWrap(false)
    T:Font(itemTitle, 13, "", T.text)
    frame.itemTitle = itemTitle

    itemHeader:SetScript("OnEnter", function(self)
        local session = DataTracker:GetCurrentRollSession()
        if not session then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if session.itemLink then
            GameTooltip:SetHyperlink(session.itemLink)
        elseif session.itemName then
            local r, g, b = ns.GetItemQualityColor(session.itemQuality or 2)
            GameTooltip:SetText(session.itemName, r or 1, g or 1, b or 1)
        end
        GameTooltip:Show()
    end)
    itemHeader:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    itemHeader:RegisterForDrag("LeftButton")
    itemHeader:SetScript("OnDragStart", function()
        frame:GetScript("OnDragStart")(frame)
    end)
    itemHeader:SetScript("OnDragStop", function()
        frame:GetScript("OnDragStop")(frame)
    end)

    -- Column Headers Row
    local colHeader = CreateFrame("Frame", nil, frame)
    colHeader:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 9, -3)
    colHeader:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -9, -3)
    colHeader:SetHeight(16)

    local hRank = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hRank:SetPoint("LEFT", 4, 0)
    hRank:SetText(L.HEADER_RANK)
    T:Font(hRank, 11, "", T.muted)

    local hName = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hName:SetPoint("LEFT", 44, 0)
    hName:SetText(L.HEADER_NAME)
    T:Font(hName, 11, "", T.muted)

    local hChoice = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hChoice:SetPoint("LEFT", 222, 0)
    hChoice:SetWidth(42)
    hChoice:SetJustifyH("CENTER")
    hChoice:SetText(L.HEADER_CHOICE)
    T:Font(hChoice, 11, "", T.muted)
    frame.hChoice = hChoice

    local hRoll = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hRoll:SetPoint("RIGHT", -4, 0)
    hRoll:SetText(L.HEADER_ROLL)
    T:Font(hRoll, 11, "", T.muted)

    local divider = colHeader:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", colHeader, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("BOTTOMRIGHT", colHeader, "BOTTOMRIGHT", 0, 0)
    Sintezza_Theme:Tint(divider, "SetColorTexture", T.line)

    -- Pure-Lua Container & ScrollBar for Player Rows (no FauxScrollFrameTemplate dependency)
    local rowContainer = CreateFrame("Frame", "Sintezza_LootRollRowContainer", frame)
    rowContainer:SetPoint("TOPLEFT", colHeader, "BOTTOMLEFT", 0, -2)
    rowContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, FOOTER_HEIGHT)
    frame.rowContainer = rowContainer

    local scrollBar = CreateFrame("Slider", "Sintezza_LootRollScrollBar", frame)
    scrollBar:SetPoint("TOPRIGHT", colHeader, "BOTTOMRIGHT", -1, -4)
    scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -11, FOOTER_HEIGHT + 4)
    scrollBar:SetWidth(8)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetValueStep(1)
    if scrollBar.SetObeyStepOnDrag then
        scrollBar:SetObeyStepOnDrag(true)
    end
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValue(0)

    T:SkinScrollBar(scrollBar, 6, 28)

    scrollBar:SetScript("OnValueChanged", function(self, value)
        if self._updating then return end
        local rounded = math.floor((value or 0) + 0.5)
        if rounded ~= frame.scrollOffset then
            frame.scrollOffset = rounded
            RollTrackerFrame:UpdatePlayerRows()
        end
    end)
    scrollBar:Hide()
    frame.scrollBar = scrollBar

    -- Create Row Pool
    frame.rows = {}
    for i = 1, MAX_VISIBLE_ROWS do
        local row = CreatePlayerRow(frame, i)
        if i == 1 then
            row:SetPoint("TOPLEFT", rowContainer, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", frame.rows[i - 1], "BOTTOMLEFT", 0, 0)
        end
        frame.rows[i] = row
    end

    -- Bottom Footer Summary
    local footerDivider = frame:CreateTexture(nil, "ARTWORK")
    footerDivider:SetHeight(1)
    footerDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, FOOTER_HEIGHT)
    footerDivider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, FOOTER_HEIGHT)
    Sintezza_Theme:Tint(footerDivider, "SetColorTexture", T.line)

    local footerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 8)
    footerText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 8)
    footerText:SetJustifyH("CENTER")
    footerText:SetWordWrap(false)
    T:Font(footerText, 11, "", T.muted)
    frame.footerText = footerText

    local footerTimer = widgets:Label(frame, "", 11, T.text)
    footerTimer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 8)
    footerTimer:SetWidth(120)
    footerTimer:SetJustifyH("RIGHT")
    footerTimer:SetWordWrap(false)
    footerTimer:Hide()
    frame.footerTimer = footerTimer
    frame:HookScript("OnHide", function()
        frame.footerSession = nil
        self:UpdateFooter()
        if ns.Settings and ns.Settings.previewDocked then ns.MultiItemManager:UpdateAnchoring() end
    end)

    -- Edit Mode / Move Mode Overlay (shown during Blizzard Edit Mode or /sloot move)
    local moverOverlay = CreateFrame("Frame", "Sintezza_LootMoverOverlay", frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    moverOverlay:SetAllPoints(frame)
    moverOverlay:SetFrameLevel(frame:GetFrameLevel() + 20)
    moverOverlay:EnableMouse(true)
    moverOverlay:RegisterForDrag("LeftButton")
    if moverOverlay.SetBackdrop then
        moverOverlay:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        moverOverlay:SetBackdropColor(0.04, 0.28, 0.65, 0.86)
        moverOverlay:SetBackdropBorderColor(0.35, 0.80, 1.00, 1.0)
    else
        local moverBg = moverOverlay:CreateTexture(nil, "BACKGROUND")
        moverBg:SetAllPoints(moverOverlay)
        moverBg:SetColorTexture(0.04, 0.28, 0.65, 0.86)
    end

    local moverLabel = moverOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    moverLabel:SetPoint("CENTER", moverOverlay, "CENTER", 0, 12)
    moverLabel:SetText(L.EDIT_MODE_LABEL)
    moverLabel:SetTextColor(1.0, 0.92, 0.50)

    local lockBtn = widgets:Button(moverOverlay, L.EDIT_MODE_LOCK_BTN, function()
        ns.TrackerAppearance:Set("locked", true)
    end)
    lockBtn:SetSize(120, 24)
    lockBtn:SetPoint("BOTTOM", moverOverlay, "BOTTOM", 0, 14)
    moverOverlay.lockBtn = lockBtn

    moverOverlay:SetScript("OnDragStart", function()
        frame:GetScript("OnDragStart")(frame)
    end)
    moverOverlay:SetScript("OnDragStop", function()
        frame:GetScript("OnDragStop")(frame)
    end)
    moverOverlay:Hide()
    frame.moverOverlay = moverOverlay

    self.frame = frame
    frame:Hide()
    ns.TrackerAppearance:Bind(frame)
    self:HookBlizzardEditMode()
end

function RollTrackerFrame:SetMoveMode(active, fromBlizzardEditMode)
    local frame = self.frame
    if not frame or not frame.moverOverlay then return end

    self.isMoveMode = active and not ns.TrackerAppearance:Get("locked") or false
    if self.isMoveMode then
        if ns.MultiItemManager and frame:GetNumPoints() == 0 then
            ns.MultiItemManager:UpdateAnchoring()
        end
        frame:SetWidth(self:GetWindowWidth())
        if fromBlizzardEditMode then
            frame.moverOverlay.lockBtn:Hide()
        else
            frame.moverOverlay.lockBtn:Show()
        end
        frame.moverOverlay:Show()
        frame:Show()
        if frame.Raise then
            frame:Raise()
        end
    else
        frame.moverOverlay:Hide()
        self:Refresh()
    end
end

function RollTrackerFrame:ToggleMoveMode()
    self:SetMoveMode(not self.isMoveMode, false)
end

function RollTrackerFrame:HookBlizzardEditMode()
    if self._editModeHooked then return end
    self._editModeHooked = true

    if EventRegistry and type(EventRegistry.RegisterCallback) == "function" then
        pcall(function()
            EventRegistry:RegisterCallback("EditMode.Enter", function()
                RollTrackerFrame:SetMoveMode(true, true)
            end, RollTrackerFrame)
            EventRegistry:RegisterCallback("EditMode.Exit", function()
                RollTrackerFrame:SetMoveMode(false, true)
            end, RollTrackerFrame)
        end)
    end

    local hookedManager
    local function HookManagerFrame()
        if _G.EditModeManagerFrame and _G.EditModeManagerFrame ~= hookedManager then
            hookedManager = _G.EditModeManagerFrame
            _G.EditModeManagerFrame:HookScript("OnShow", function()
                RollTrackerFrame:SetMoveMode(true, true)
            end)
            _G.EditModeManagerFrame:HookScript("OnHide", function()
                RollTrackerFrame:SetMoveMode(false, true)
            end)
        end
    end

    HookManagerFrame()
    ns:RegisterEvent("ADDON_LOADED", function(_, loadedName)
        if loadedName == "Blizzard_EditMode" then
            HookManagerFrame()
        end
    end)
end

function RollTrackerFrame:HideWindow()
    if self.frame then
        self.frame:Hide()
    end
end

function RollTrackerFrame:ForceShowCurrent()
    local session = DataTracker:GetCurrentRollSession()
    if not session then
        local lastID = DataTracker.GetLastRollID and DataTracker:GetLastRollID()
        if lastID then
            DataTracker:UndismissRoll(lastID)
            DataTracker:SetCurrentRollID(lastID, true)
            return
        end
    else
        DataTracker:UndismissRoll(session.rollID)
    end
    self:Refresh(true)
end

function RollTrackerFrame:UpdateTabs(activeRolls, currentRollID)
    local frame = self.frame
    if not frame then return end

    local showTabs = (#activeRolls > 1)
    for i = 1, MAX_TABS do
        local tab = frame.tabs[i]
        local rollSession = showTabs and activeRolls[i] or nil
        if rollSession then
            tab.rollID = rollSession.rollID
            tab.itemLink = rollSession.itemLink
            tab.itemName = rollSession.itemName
            tab.icon:SetTexture(rollSession.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
            local r, g, b = ns.GetItemQualityColor(rollSession.itemQuality)
            T:PaintItemBorder(tab.iconBorder, rollSession.itemQuality, r, g, b)

            local eval = DataTracker:EvaluateSession(rollSession)
            if eval then
                tab.badge:SetText(string.format("%d/%d", eval.answeredPlayers, eval.totalPlayers))
            else
                tab.badge:SetText("")
            end

            local active = rollSession.rollID == currentRollID
            T:PaintButton(tab, active)
            tab.icon:SetDesaturated(false)
            tab.icon:SetAlpha(active and 1 or .65)
            tab:Show()
            ns.RollEffects:NewItem(rollSession, tab, true)
        else
            tab:Hide()
        end
    end
end

function RollTrackerFrame:UpdatePlayerRows()
    local frame = self.frame
    if not frame or not self.currentEval then return end

    local allPlayers = self.currentEval.players or {}
    local players = {}
    for _, p in ipairs(allPlayers) do
        local skip = false
        if ns.db.hidePassed and p.rollType == DataTracker.ROLL_TYPE_PASS then
            skip = true
        elseif ns.db.hidePending and p.rollType == DataTracker.ROLL_TYPE_PENDING then
            skip = true
        end
        if not skip then
            table.insert(players, p)
        end
    end

    local numPlayers = #players
    local visibleRows = math.min(MAX_VISIBLE_ROWS, math.max(MIN_VISIBLE_ROWS, numPlayers))

    -- Adjust window width & height dynamically to fit choice mode and party/raid size cleanly
    local winWidth = self:GetWindowWidth()
    local targetHeight = HEADER_HEIGHT + (visibleRows * ROW_HEIGHT) + FOOTER_HEIGHT
    frame:SetSize(winWidth, targetHeight)

    local choiceMode = self:GetChoiceDisplayMode()
    if frame.hChoice then
        frame.hChoice:ClearAllPoints()
        frame.hChoice:SetPoint("LEFT", 222, 0)
        if choiceMode == "ICONS" then
            frame.hChoice:SetWidth(42)
            frame.hChoice:SetJustifyH("CENTER")
        elseif choiceMode == "TEXT" then
            frame.hChoice:SetWidth(78)
            frame.hChoice:SetJustifyH("LEFT")
        else
            frame.hChoice:SetWidth(96)
            frame.hChoice:SetJustifyH("LEFT")
        end
    end

    local maxOffset = math.max(0, numPlayers - visibleRows)
    frame.maxScrollOffset = maxOffset
    local offset = frame.scrollOffset or 0
    if offset > maxOffset then
        offset = maxOffset
        frame.scrollOffset = offset
    elseif offset < 0 then
        offset = 0
        frame.scrollOffset = 0
    end

    local hasScrollbar = (numPlayers > visibleRows)
    if frame.scrollBar then
        if hasScrollbar then
            frame.scrollBar._updating = true
            frame.scrollBar:SetMinMaxValues(0, maxOffset)
            frame.scrollBar:SetValue(offset)
            frame.scrollBar._updating = false
            frame.scrollBar:Show()
        else
            frame.scrollBar:Hide()
        end
    end

    local rowWidth = hasScrollbar and (winWidth - 34) or (winWidth - 20)
    local session = DataTracker:GetCurrentRollSession()
    local winner = session and session.winner
    local leaders = self.currentEval.leaders or {}
    local isLeaderMap = {}
    for _, l in ipairs(leaders) do
        isLeaderMap[l] = true
    end

    for i = 1, MAX_VISIBLE_ROWS do
        local row = frame.rows[i]
        local dataIdx = offset + i

        if i <= visibleRows and dataIdx <= numPlayers then
            local p = players[dataIdx]
            local isWinner = winner and ((winner.isSelf and p.isSelf) or winner.name == p.name or winner.name == p.fullName)
            local isLeader = not winner and isLeaderMap[p] == true
            row:SetWidth(rowWidth)
            row.playerData = p

            -- Subtle highlight for leading row(s)
            if isWinner then
                Sintezza_Theme:Tint(row.bg, "SetColorTexture", T.accent, .19)
                Sintezza_Theme:Tint(row.rankText, "SetTextColor", T.accent)
            elseif isLeader then
                row.bg:SetColorTexture(0.85, 0.68, 0.15, 0.18)
                row.rankText:SetTextColor(1.0, 0.85, 0.15)
            else
                if (row.rowIndex or i) % 2 == 1 then
                    row.bg:SetColorTexture(1, 1, 1, 0.04)
                else
                    row.bg:SetColorTexture(0, 0, 0, 0.15)
                end
                row.rankText:SetTextColor(0.8, 0.8, 0.8)
            end

            -- 1. Rank ("1.", "2.")
            row.rankText:SetText(dataIdx .. ".")

            -- 2. Class Icon
            local coords = p.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[p.class]
            if coords then
                row.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
                row.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                row.classIcon:Show()
            else
                row.classIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                row.classIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.classIcon:Show()
            end

            -- 3. Class-Colored Player Name
            row.nameText:SetText(ns.RosterInspector:ColorizeName(p.name, p.class))

            -- 4. Role Icon
            local roleCoords = ns.db.showRoleIcons and p.role and ROLE_TEX_COORDS[p.role]
            if roleCoords then
                row.roleIcon:SetTexCoord(roleCoords[1], roleCoords[2], roleCoords[3], roleCoords[4])
                row.roleIcon:Show()
            else
                row.roleIcon:Hide()
            end

            -- 5. Roll Choice Icon & Text
            local iconPath = ROLL_ICONS[p.rollType]
            local rc = ROLL_COLORS[p.rollType] or ROLL_COLORS[DataTracker.ROLL_TYPE_PENDING]

            row.choiceText:SetJustifyH("LEFT")
            if p.rollType == DataTracker.ROLL_TYPE_PENDING then
                row.choiceIcon:Hide()
                row.choiceText:ClearAllPoints()
                row.choiceText:SetPoint("LEFT", row, "LEFT", 222, 0)
                if choiceMode == "ICONS" then
                    row.choiceText:SetWidth(42)
                    row.choiceText:SetJustifyH("CENTER")
                    row.choiceText:SetText("···")
                else
                    row.choiceText:SetWidth(78)
                    row.choiceText:SetText(L.CHOICE_WAITING)
                end
                row.choiceText:SetTextColor(unpack(T.muted))
                row.choiceText:Show()
            elseif choiceMode == "ICONS" then
                row.choiceText:Hide()
                if iconPath then
                    row.choiceIcon:ClearAllPoints()
                    row.choiceIcon:SetPoint("CENTER", row, "LEFT", 243, 0)
                    row.choiceIcon:SetTexture(iconPath)
                    row.choiceIcon:Show()
                else
                    row.choiceIcon:Hide()
                end
            elseif choiceMode == "TEXT" then
                row.choiceIcon:Hide()
                row.choiceText:ClearAllPoints()
                row.choiceText:SetPoint("LEFT", row, "LEFT", 222, 0)
                row.choiceText:SetWidth(78)
                row.choiceText:SetText(DataTracker:GetRollTypeLabel(p.rollType))
                row.choiceText:SetTextColor(rc.r, rc.g, rc.b)
                row.choiceText:Show()
            else
                if iconPath then
                    row.choiceIcon:ClearAllPoints()
                    row.choiceIcon:SetPoint("LEFT", row, "LEFT", 222, 0)
                    row.choiceIcon:SetTexture(iconPath)
                    row.choiceIcon:Show()

                    row.choiceText:ClearAllPoints()
                    row.choiceText:SetPoint("LEFT", row.choiceIcon, "RIGHT", 4, 0)
                    row.choiceText:SetWidth(76)
                    row.choiceText:SetText(DataTracker:GetRollTypeLabel(p.rollType))
                    row.choiceText:SetTextColor(rc.r, rc.g, rc.b)
                    row.choiceText:Show()
                else
                    row.choiceIcon:Hide()
                    row.choiceText:Hide()
                end
            end

            -- 6. Roll Score
            if p.rollScore and p.rollScore > 0 then
                row.scoreText:SetText(tostring(p.rollScore))
                if isLeader then
                    row.scoreText:SetTextColor(1.0, 0.85, 0.15)
                else
                    row.scoreText:SetTextColor(1.0, 1.0, 1.0)
                end
            elseif p.rollType == DataTracker.ROLL_TYPE_PASS or p.rollType == DataTracker.ROLL_TYPE_PENDING then
                row.scoreText:SetText("-")
                row.scoreText:SetTextColor(0.55, 0.55, 0.55)
            else
                row.scoreText:SetText("...")
                row.scoreText:SetTextColor(0.55, 0.55, 0.55)
            end

            row:Show()
        else
            row.playerData = nil
            row:Hide()
        end
    end
end

local function PaintRollTime(frame, remaining)
    local seconds = math.ceil(remaining)
    if frame.footerSeconds == seconds then return end
    frame.footerSeconds = seconds
    frame.footerTimer:SetFormattedText(L.FOOTER_TIME_LEFT, math.floor(seconds / 60), seconds % 60)
end

local function TickRollTimer(frame)
    local remaining = DataTracker:GetRollTimeLeft(frame.footerSession)
    if remaining and remaining > 0 then
        PaintRollTime(frame, remaining)
    else
        RollTrackerFrame:UpdateFooter()
    end
end

function RollTrackerFrame:UpdateFooter()
    local frame = self.frame
    local session, eval = frame.footerSession, self.currentEval
    local remaining = ns.db.showRollTimer and DataTracker:GetRollTimeLeft(session) or nil
    local ticking = remaining ~= nil and remaining > 0
    local footer = frame.footerText
    if frame.footerTicking ~= ticking then
        frame.footerTicking = ticking
        frame.footerTimer:SetShown(ticking)
        frame:SetScript("OnUpdate", ticking and TickRollTimer or nil)
        footer:ClearAllPoints()
        footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 8)
        if ticking then
            footer:SetPoint("BOTTOMRIGHT", frame.footerTimer, "BOTTOMLEFT", -8, 0)
            footer:SetJustifyH("LEFT")
        else
            footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 8)
            footer:SetJustifyH("CENTER")
            frame.footerSeconds = nil
        end
    end

    local summary = ""
    if session and eval then
        local winner = session.winner
        if winner then
            local outcome = winner.isSelf and L.HISTORY_YOU_WON or L.HISTORY_WINNER:format(winner.name or L.HISTORY_UNKNOWN)
            summary = winner.score and (outcome .. " · " .. winner.score) or outcome
        elseif session.allPassed then
            summary = L.WINNER_ALL_PASSED
        elseif eval.isComplete then
            summary = L.FOOTER_COMPLETE:format(eval.answeredPlayers, eval.totalPlayers)
        elseif remaining == 0 then
            summary = L.FOOTER_AWAITING_RESULT
        elseif ticking then
            summary = L.FOOTER_ANSWERS:format(eval.answeredPlayers, eval.totalPlayers)
            PaintRollTime(frame, remaining)
        else
            summary = L.FOOTER_SUMMARY:format(eval.answeredPlayers, eval.totalPlayers, eval.pendingCount)
        end
    end
    footer:SetText(summary)
end

function RollTrackerFrame:Refresh(forceShow)
    local frame = self.frame
    if not frame then return end

    frame:SetWidth(self:GetWindowWidth())

    local session = DataTracker:GetCurrentRollSession()
    if not session or (not ns.db.enabled and not session.isSimulated) then
        frame.footerSession = nil
        self:UpdateFooter()
        if not self.isMoveMode then
            frame:Hide()
        end
        return
    end

    if DataTracker:IsDismissed(session.rollID) then
        if not self.isMoveMode then
            frame:Hide()
        end
        return
    end

    if not forceShow and not session.isSimulated and not ns.db.autoOpen and not frame:IsShown() then
        return
    end

    frame:Show()
    local activeRolls = DataTracker:GetActiveRolls()
    self:UpdateTabs(activeRolls, session.rollID)
    if #activeRolls <= 1 then ns.RollEffects:NewItem(session, frame, false) end

    -- Item Header (use plain itemName colored by quality, without hyperlink [brackets])
    frame.itemIcon:SetTexture(session.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
    local r, g, b = ns.GetItemQualityColor(session.itemQuality or 2)
    T:PaintItemBorder(frame.itemBorder, session.itemQuality, r, g, b)
    local cleanName = session.itemName
    if (not cleanName or cleanName == "") and session.itemLink then
        cleanName = session.itemLink:match("%[(.-)%]") or session.itemLink
    end
    frame.itemTitle:SetText(cleanName or L.ITEM_FALLBACK)
    frame.itemTitle:SetTextColor(r or 1, g or 1, b or 1)

    -- Evaluate Player List & Leaders
    self.currentEval = DataTracker:EvaluateSession(session)
    frame.footerSession = session
    self:UpdateFooter()

    self:UpdatePlayerRows()
    ns.TrackerAppearance:ApplyTo(frame)
    frame:Show()
    if frame.Raise then
        frame:Raise()
    end
end
