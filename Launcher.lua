local addonName, ns = ...
local Launcher = {}
ns.Launcher = Launcher

function Launcher:RegisterSettings(title, open)
    if self.category or not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local theme = ns.SettingsTheme or ns.Theme
    local widgets = Sintezza_Theme:CreateWidgets(theme)
    local panel = CreateFrame("Frame")
    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetText(title)
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("TOPLEFT", 18, -18)
    icon:SetTexture(Sintezza_Theme.icons[addonName])
    heading:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    theme:Font(heading, 16, "", theme.text, "display")

    local button = widgets:Button(panel, ns.L.OPEN_SETTINGS, function()
        if SettingsPanel and SettingsPanel:IsShown() and not InCombatLockdown() then HideUIPanel(SettingsPanel) end
        open()
    end)
    button:SetSize(184, 28)
    button:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -16)

    self.category = Settings.RegisterCanvasLayoutCategory(panel, title)
    Settings.RegisterAddOnCategory(self.category)
end

function Launcher:RefreshMinimap(db)
    if self.icon then self.icon:Refresh(db) end
end

function Launcher:RegisterMinimap(title, icon, db, openHistory)
    if self.icon then self:RefreshMinimap(db); return end
    self.icon = Sintezza_Theme:CreateMinimapButton(addonName, icon, db,
        function(_, button)
            if button == "LeftButton" or button == "RightButton" then openHistory() end
        end,
        function(tooltip)
            tooltip:AddLine(title)
            tooltip:AddLine(ns.L.HISTORY_TITLE, 1, 1, 1)
        end)
end
