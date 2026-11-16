local _, ns = ...
local shared = Sintezza_Theme
ns.InterfaceFonts = shared.Fonts
ns.Theme = shared:ForAddon(function() return ns.db end)
