local function noop() end
local methods = {}
local function widget(kind)
    return setmetatable({ kind = kind, scripts = {}, shown = true, points = {} }, { __index = methods })
end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:SetShown(value) self.shown = not not value end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:SetHeight(value) self.height = value end
function methods:SetWidth(value) self.width = value end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetText(value) self.textValue = value end
function methods:GetText() return self.textValue or "" end
function methods:CreateTexture() return widget("Texture") end
function methods:SetTexture(value) self.texture = value end
function methods:SetAtlas(value) self.texture = value end
function methods:SetBackdropColor(...) self.fill = { ... } end
function methods:SetBackdropBorderColor(...) self.outline = { ... } end
function methods:SetSelected(value) self.selected = value end
function methods:SetExpanded(value) self.expanded = value end
for _, name in ipairs({ "SetJustifyH", "SetWordWrap", "SetAllPoints", "EnableMouseMotion", "SetTextColor", "SetVerticalScroll", "RefreshRange" }) do methods[name] = noop end
function CreateFrame(kind) return widget(kind) end
GameTooltip = { Hide = noop }
date = function() return "17.11 01:00" end

local ns, H = FreshHistory()
local T = { muted = { .6, .6, .6 }, text = { 1, 1, 1 }, accent = { .8, .5, .3 },
    accentDim = { .2, .1, .05 }, panel = { .1, .1, .1 }, input = { .05, .05, .05 } }
local sharedCalls = { band = 0, hover = 0, arrow = 0 }
function T:RowBand() sharedCalls.band = sharedCalls.band + 1; return widget("Band") end
function T:MenuHighlight() sharedCalls.hover = sharedCalls.hover + 1; local w = widget("Hover"); w:Hide(); return w end
function T:DisclosureArrow() sharedCalls.arrow = sharedCalls.arrow + 1; return widget("Arrow") end
function T:FrameIcon() return widget("IconBorder") end
T.Backdrop, T.PaintItemBorder = noop, noop
ns.Theme = T
function Sintezza_Theme:Tint(target, method, color, alpha)
    target[method](target, color[1], color[2], color[3], alpha or color[4] or 1)
end
function Sintezza_Theme:CreateWidgets()
    return {
        Label = function(_, parent, text) local w = widget("Text"); w:SetText(text); return w end,
        NavButton = function() local w = widget("Navigation"); w.text = widget("Text"); return w end,
        Button = function() error("Item rows must not create an expand button") end,
    }
end
ns.GetItemQualityColor = function() return 0, 1, 0 end
ns.DataTracker.ROLL_TYPE_PASS = 0
ns.DataTracker.ROLL_ICONS = { [1] = "need", [2] = "greed" }
ns.DataTracker.GetRollTypeLabel = function() return "Need" end
ns.RosterInspector.ColorizeName = function(_, name) return name end
ns.RosterInspector.GetClassColorHex = function() return "ffffffff" end
assert(loadfile(ADDON_ROOT .. "/UI/History.lua"))("Sintezza_Loot", ns)
H.tab, H.itemRows, H.playerRows, H.runRows = "runs", {}, {}, {}
for _, key in ipairs({ "frame", "search", "heading", "meta", "empty", "playerDetails", "playerHeader", "noPlayers",
    "itemBody", "itemScroll", "currentLabel", "archiveLabel", "runBody", "runScroll" }) do H[key] = widget(key) end
H.frame:Hide()
local first = {
    historyRunID = H.insideRunID, historyRun = H:GetActiveRun(), itemName = "Item one", itemTexture = 123,
    players = { { name = "Tester", isSelf = true, rollType = 2, rollScore = 40 }, { name = "Winner", rollType = 1, rollScore = 46 } },
    winner = { name = "Winner" },
}
H:Record(first)
local second = {
    historyRunID = H.insideRunID, historyRun = H:GetActiveRun(), itemName = "Item two", itemTexture = 123,
    players = { { name = "Tester", isSelf = true, rollType = 1, rollScore = 90 }, { name = "Other", rollType = 1, rollScore = 46 } },
    winner = { name = "Tester", isSelf = true },
}
H:Record(second)
H:Refresh()
assert(#H.itemRows == 2 and sharedCalls.arrow == 2 and sharedCalls.band == 2 and sharedCalls.hover == 2)
local row = H.itemRows[1]
assert(not row.disclosure and not row.chevron.expanded)
row.scripts.OnEnter(row); assert(row.hover.shown)
row.scripts.OnLeave(row); assert(not row.hover.shown)
row.scripts.OnClick()
assert(row.chevron.expanded and H.entry == second.historyEntry)
assert(H.playerRows[1].tag.textValue == ns.L.HISTORY_WINNER_TAG)
assert(H.playerRows[1].outline[4] == .45 and H.playerRows[2].outline[4] == 0)
H.itemRows[2].scripts.OnClick()
assert(not row.chevron.expanded and H.itemRows[2].chevron.expanded)
assert(H.playerRows[1].outline[4] == 0 and H.playerRows[2].outline[4] == .45)
assert(H.playerRows[2].tag.textValue == "")
H.itemRows[2].scripts.OnClick()
assert(not H.entry and not H.playerDetails.shown)
print("PASS: shared list components, row expand/collapse, hover, pooled self outline for win/loss")
