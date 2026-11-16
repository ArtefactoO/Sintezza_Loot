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
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(false)
        T:Backdrop(frame, T.header, T.brass)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(30, 30)
        icon:SetPoint("LEFT", 9, 0)
        frame.icon = icon
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
    frame.name:SetText(session.itemName or (session.itemLink and session.itemLink:match("%[(.-)%]")) or L.ITEM_FALLBACK)
    frame:Show()
    frame.playLootGlint()
    if self.winTimer then self.winTimer:Cancel() end
    self.winTimer = C_Timer.NewTimer(1.5, function() frame:Hide(); self.winTimer = nil end)
end
