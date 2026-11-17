local addonName, ns = ...
local Launcher = {}
ns.Launcher = Launcher

function Launcher:RegisterSettings(title, open)
    local shared = Sintezza_Theme
    if self.category or not shared.RegisterLauncherPage then return end
    self.category = shared:RegisterLauncherPage({
        title = title,
        icon = shared.icons[addonName],
        buttonLabel = ns.L.OPEN_SETTINGS,
        open = open,
        appearance = ns.SettingsTheme or ns.Theme,
    })
end

function Launcher:RefreshMinimap(db)
    if self.icon then self.icon:Refresh(db) end
end

function Launcher:RegisterMinimap(title, icon, db, openHistory)
    if self.icon then self:RefreshMinimap(db); return end
    self.icon = Sintezza_Theme:CreateMinimapButton(addonName, icon, db,
        openHistory,
        function(tooltip)
            tooltip:AddLine(title)
            tooltip:AddLine(ns.L.HISTORY_TITLE, 1, 1, 1)
            Sintezza_Theme:AddMinimapToggleHint(tooltip)
        end)
end
