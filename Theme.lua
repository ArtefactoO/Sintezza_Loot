local _, ns = ...
local shared = Sintezza_Theme
ns.InterfaceFonts = shared.Fonts
ns.Theme = shared:ForAddon(function() return ns.db end)

local transparent = { 0, 0, 0, 0 }

function ns:FrameItemIcon(parent, icon)
    icon:SetTexCoord(.10, .90, .10, .90)
    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    ns.Theme:Backdrop(border, transparent, transparent)
    return border
end
