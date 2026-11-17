local _, ns = ...
local T, L = ns.Theme, ns.L
local Effects = {}
ns.RollEffects = Effects

local function Flash(parent, duration, width, travel, peak)
    local texture = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    texture:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 3, 1)
    texture:SetSize(width, 2)
    texture:SetColorTexture(.96, .74, .42, 1)
    texture:Hide()
    local group = texture:CreateAnimationGroup()
    local move = group:CreateAnimation("Translation")
    move:SetOffset(travel, 0)
    move:SetDuration(duration)
    move:SetSmoothing("OUT")
    move:SetOrder(1)
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(peak)
    fade:SetToAlpha(0)
    fade:SetDuration(duration)
    fade:SetOrder(1)
    group:SetScript("OnFinished", function() texture:Hide() end)
    parent:HookScript("OnHide", function() group:Stop(); texture:Hide() end)
    return function()
        group:Stop()
        texture:Show()
        group:Play()
    end
end

function Effects:NewItem(session, anchor, isTab)
    if session.itemGlintShown or session.isDone or not ns.db.animateNewRoll then return end
    session.itemGlintShown = true
    if not anchor.playLootGlint then
        anchor.playLootGlint = Flash(anchor, .24, isTab and 9 or 40, isTab and 15 or 165, .85)
    end
    anchor.playLootGlint()
end

function Effects:ShowWin(session)
    if not ns:ShowsSintezzaWin() then return end
    local frame = self.win
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetSize(292, 48)
        frame:SetPoint("TOP", UIParent, "TOP", 0, -172)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:EnableMouse(false)
        T:Backdrop(frame, T.header, T.brass)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(30, 30)
        icon:SetPoint("LEFT", 9, 0)
        frame.icon = icon
        frame.itemBorder = ns:FrameItemIcon(frame, icon)
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        T:Font(title, 13, "", T.accent)
        title:SetText(L.HISTORY_YOU_WON)
        title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
        local name = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        T:Font(name, 11, "", T.text)
        name:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 0)
        name:SetPoint("RIGHT", -12, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        frame.name = name
        frame.playLootGlint = Flash(frame, .48, 48, 232, 1)
        self.win = frame
    end
    frame.icon:SetTexture(session.itemTexture or 134400)
    local r, g, b = ns.GetItemQualityColor(session.itemQuality)
    frame.itemBorder:SetBackdropBorderColor(r, g, b, .9)
    frame.name:SetTextColor(r, g, b, 1)
    frame.name:SetText(session.itemName or (session.itemLink and session.itemLink:match("%[(.-)%]")) or L.ITEM_FALLBACK)
    frame:Show()
    frame.playLootGlint()
    if self.winTimer then self.winTimer:Cancel() end
    self.winTimer = C_Timer.NewTimer(1.5, function() frame:Hide(); self.winTimer = nil end)
end

local function CanStyle(region)
    if ns.IsSecretValue(region) or not region then return false end
    if region.IsForbidden then
        local forbidden = region:IsForbidden()
        if ns.IsSecretValue(forbidden) or forbidden then return false end
    end
    if region.CanBeAccessedInContext then
        local accessible = region:CanBeAccessedInContext()
        if ns.IsSecretValue(accessible) or not accessible then return false end
    end
    return true
end

function Effects:PreviewWin(item)
    self:ShowWin(item)
    if not ns:ShowsBlizzardWin() then return end

    local alerts = LootAlertSystem
    if InCombatLockdown() or not item.itemLink or not CanStyle(AlertFrame)
        or not alerts or type(alerts.AddAlert) ~= "function"
        or (type(alerts.CanShowMore) == "function" and not alerts:CanShowMore()) then
        ns:Print(L.WIN_PREVIEW_UNAVAILABLE)
        return
    end

    local shown, accepted = pcall(alerts.AddAlert, alerts, item.itemLink, 1, ns.DataTracker.ROLL_TYPE_NEED, 100)
    if not shown or accepted == false then ns:Print(L.WIN_PREVIEW_UNAVAILABLE) end
end

local function EllesmereStylesRolls()
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
    if not isLoaded or not isLoaded("EllesmereUIBlizzardSkin") then return false end
    local getStyle = EllesmereUI and EllesmereUI.GetBlizzWindowStyle
    if type(getStyle) == "function" then return getStyle("lootroll") ~= "off" end
    return not EllesmereUIDB or EllesmereUIDB.reskinLootRoll ~= false
end

local function StyleGroupRoll(frame)
    if not CanStyle(frame) then return end
    local item, timer = frame.IconFrame, frame.Timer
    if not CanStyle(item) or not CanStyle(timer) then return end
    for _, region in ipairs({ "Background", "Border", "Name" }) do
        if not CanStyle(frame[region]) then return end
    end
    for _, region in ipairs({ "Icon", "Count" }) do
        if not CanStyle(item[region]) then return end
    end
    if not CanStyle(timer.Background) then return end

    -- Blizzard keeps the timer below the popup. Put the surface behind its fill on the same frame.
    local edge = timer:CreateTexture(nil, "BACKGROUND", nil, -3)
    edge:SetAllPoints(frame)
    Sintezza_Theme:Tint(edge, "SetColorTexture", T.line)
    local background = timer:CreateTexture(nil, "BACKGROUND", nil, -2)
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    Sintezza_Theme:Tint(background, "SetColorTexture", T.bg)

    frame.Background:SetAlpha(0)
    frame.Border:SetAlpha(0)
    item.Icon:SetTexCoord(.08, .92, .08, .92)
    ns.InterfaceFonts:ApplyTheme(frame.Name, 12, "")
    ns.InterfaceFonts:ApplyTheme(item.Count, 10, "OUTLINE")

    timer.Background:SetAlpha(0)
    timer:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    Sintezza_Theme:Tint(timer, "SetStatusBarColor", T.accent)
end

function Effects:Init()
    if not ns.IsForever then return end
    local pending
    local function Apply()
        pending = InCombatLockdown()
        if pending then return end
        for index = 1, 4 do
            StyleGroupRoll(_G["GroupLootFrame" .. index])
        end
    end
    ns:RegisterEvent("PLAYER_LOGIN", function()
        if ns.db.skinGroupLoot == true and not EllesmereStylesRolls() then Apply() end
    end)
    ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if pending then Apply() end
    end)
end
