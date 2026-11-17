local _, ns = ...
local L, T, D, H = ns.L, ns.Theme, ns.DataTracker, ns.History
local W = Sintezza_Theme:CreateWidgets(T)
local ITEM_HEIGHT, PLAYER_HEIGHT = 38, 23
local CONTENT_TOP, LIST_TOP = -135, -177

local function Text(parent, size, color, justify)
    local label = W:Label(parent, "", size, color)
    label:SetJustifyH(justify or "LEFT")
    label:SetWordWrap(false)
    return label
end

local function Scroll(parent, x, y, right, bottom)
    local scroll, body, bar = W:ScrollFrame(parent)
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", right, bottom)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    scroll:HookScript("OnSizeChanged", function(_, width)
        body:SetWidth(math.max(1, width))
        scroll:RefreshRange()
    end)
    body:SetWidth(math.max(1, scroll:GetWidth()))
    return scroll, body
end

local function RollCount(count)
    local form = L.HISTORY_ROLL_MANY
    if L.HISTORY_ROLL_FEW then
        local last, lastTwo = count % 10, count % 100
        if last == 1 and lastTwo ~= 11 then form = L.HISTORY_ROLL_ONE
        elseif last >= 2 and last <= 4 and (lastTwo < 12 or lastTwo > 14) then form = L.HISTORY_ROLL_FEW end
    elseif count == 1 then
        form = L.HISTORY_ROLL_ONE
    end
    return count .. " " .. form
end

local function TimeLabel(run)
    if not run then return "" end
    local start = date("%d.%m %H:%M", run.startedAt)
    if run.endedAt then return start .. "–" .. date("%H:%M", run.endedAt) end
    if run.endReason == "imported" then return start end
    return L.HISTORY_SINCE:format(start)
end

local function LayoutRow(row, parent, y, height, inset)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", inset or 0, -y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(inset or 0), -y)
    row:Show()
    return y + height
end

local function CreateRunRow(parent)
    local row = W:NavButton(parent, "", "", function() end)
    row:SetHeight(43)
    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", 26, -5)
    row.text:SetPoint("TOPRIGHT", -5, -5)
    row.meta = Text(row, 10, T.muted)
    row.meta:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
    row.meta:SetPoint("TOPRIGHT", row.text, "BOTTOMRIGHT", 0, -2)
    row:SetScript("OnClick", function(self)
        if self.groupKey ~= H.selected then
            H.selected = self.groupKey
            H.entry = nil
            H:Refresh(true, true)
        end
    end)
    return row
end

local function ShowChoiceTooltip(self)
    if self.choice then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.choice)
        GameTooltip:Show()
    end
end

local function ChoiceHover(row, texture)
    local hover = CreateFrame("Frame", nil, row)
    hover:SetAllPoints(texture)
    hover:EnableMouseMotion(true)
    hover:SetScript("OnEnter", ShowChoiceTooltip)
    hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return hover
end

local function CreateItemRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ITEM_HEIGHT)
    row.band = T:RowBand(row)
    row.hover = T:MenuHighlight(row)
    row:SetScript("OnEnter", function(self) self.hover:Show() end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    row:SetScript("OnHide", function(self) self.hover:Hide() end)
    row.chevron = T:DisclosureArrow(row, 10)
    row.chevron:SetPoint("LEFT", 7, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", 23, 0)
    row.border = ns:FrameItemIcon(row, row.icon)
    local function ToggleRoll()
        H.entry = H.entry ~= row.entry and row.entry or nil
        H:Refresh()
    end
    row.outcome = Text(row, 11, T.muted, "RIGHT")
    row.outcome:SetPoint("RIGHT", -10, 0)
    row.outcome:SetWidth(132)
    row.outcomeIcon = row:CreateTexture(nil, "ARTWORK")
    row.outcomeIcon:SetSize(16, 16)
    row.outcomeIcon:SetPoint("RIGHT", row.outcome, "RIGHT", 0, 0)
    row.outcomeHover = ChoiceHover(row, row.outcomeIcon)
    row.name = Text(row, 12, T.text)
    row.name:SetPoint("TOPLEFT", 53, -5)
    row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -152, -5)
    row.meta = Text(row, 10, T.muted)
    row.meta:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.meta:SetPoint("TOPRIGHT", row.name, "BOTTOMRIGHT", 0, -2)
    local iconHover = CreateFrame("Frame", nil, row)
    iconHover:SetAllPoints(row.icon)
    iconHover:EnableMouseMotion(true)
    iconHover:SetScript("OnEnter", function(self)
        local link = row.entry and row.entry.link
        if type(link) == "string" and link:find("|Hitem:", 1, true) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end
    end)
    iconHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", ToggleRoll)
    return row
end

local function CreatePlayerRow(parent)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(PLAYER_HEIGHT)
    T:Backdrop(row, T.input, T.input)
    row.name = Text(row, 11, T.text)
    row.name:SetPoint("LEFT", 10, 0)
    row.name:SetPoint("RIGHT", row, "CENTER", 4, 0)
    row.tag = Text(row, 10, T.accent)
    row.tag:SetPoint("LEFT", row, "CENTER", 9, 0)
    row.tag:SetWidth(99)
    row.choice = Text(row, 11, T.muted)
    row.choice:SetPoint("LEFT", row, "RIGHT", -138, 0)
    row.choice:SetWidth(90)
    local hover = CreateFrame("Frame", nil, row)
    hover:SetSize(25, 23)
    hover:SetPoint("LEFT", row.choice, "LEFT", 0, 0)
    hover:EnableMouseMotion(true)
    hover:SetScript("OnEnter", ShowChoiceTooltip)
    hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.choiceHover = hover
    row.icon = hover:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT")
    row.score = Text(row, 11, T.text, "RIGHT")
    row.score:SetPoint("RIGHT", -13, 0)
    row.score:SetWidth(35)
    return row
end

local function ChoiceText(player)
    if player.rollDetail == 1 then return L.HISTORY_OFF_SPEC end
    if player.rollDetail == 2 then return L.HISTORY_TRANSMOG end
    if player.rollDetail == 4 then return L.HISTORY_NO_ROLL end
    if player.choice == nil or player.choice == D.ROLL_TYPE_PENDING then return L.HISTORY_UNKNOWN end
    return D:GetRollTypeLabel(player.choice)
end

local function SetChoiceIcon(texture, choice, detail)
    if detail == 2 then
        texture:SetAtlas("lootroll-icon-transmog")
        return true
    end
    local path = choice ~= D.ROLL_TYPE_PASS and D.ROLL_ICONS[choice]
    texture:SetTexture(path or nil)
    return path ~= nil and path ~= false
end

local function ShowPersonalOutcome(row, entry)
    local winner = entry.winner
    local choice, detail = winner.choice or entry.choice
    for _, player in ipairs(entry.players or {}) do
        if player.isSelf then
            choice, detail = choice or player.choice, player.rollDetail
            break
        end
    end
    local hasIcon = SetChoiceIcon(row.outcomeIcon, choice, detail)
    local label = ChoiceText({ choice = choice, rollDetail = detail })
    row.outcomeIcon:SetShown(hasIcon)
    row.outcomeHover:SetShown(hasIcon)
    row.outcomeHover.choice = label
    row.outcome:SetText(hasIcon and "" or label)
end

function H:ShowPlayers(entry, y, query)
    local body = self.playerDetails
    local detailY = LayoutRow(self.playerHeader, body, 0, PLAYER_HEIGHT, 4)
    local players = entry.players or {}
    local winner = entry.winner
    local winnerName = winner and winner.name and ns.RosterInspector:GetShortName(winner.name)
    for i, player in ipairs(players) do
        local row = self.playerRows[i]
        if not row then
            row = CreatePlayerRow(body)
            self.playerRows[i] = row
        end
        local won = winner and ((winner.isSelf and player.isSelf) or (winnerName and winnerName == player.name))
        local tag = won and L.HISTORY_WINNER_TAG or ""
        local name = player.name or L.HISTORY_UNKNOWN
        local matched = query ~= "" and self:Matches(name, query)
        local label = ChoiceText(player)
        local hasIcon = SetChoiceIcon(row.icon, player.choice, player.rollDetail)
        row.name:SetText(matched and name or ns.RosterInspector:ColorizeName(name, player.class))
        Sintezza_Theme:Tint(row.name, "SetTextColor", matched and T.accent or T.text)
        row.tag:SetText(tag)
        row.choiceHover.choice = hasIcon and label or nil
        row.choiceHover:SetShown(hasIcon)
        row.choice:SetText(hasIcon and "" or label)
        row.score:SetText(player.score or "—")
        Sintezza_Theme:Tint(row, "SetBackdropColor", won and T.accentDim or (i % 2 == 0 and T.panel or T.input))
        Sintezza_Theme:Tint(row, "SetBackdropBorderColor", T.accent, player.isSelf and .45 or 0)
        detailY = LayoutRow(row, body, detailY, PLAYER_HEIGHT, 4)
    end
    if #players == 0 then
        self.noPlayers:ClearAllPoints()
        self.noPlayers:SetPoint("TOPLEFT", body, "TOPLEFT", 15, -detailY)
        self.noPlayers:Show()
        detailY = detailY + PLAYER_HEIGHT
    end
    body:SetHeight(detailY)
    return LayoutRow(body, self.itemBody, y, detailY, 8) + 7
end

function H:Create()
    local frame = CreateFrame("Frame", "Sintezza_LootHistoryFrame", UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(720, 488)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    T:WindowSurface(frame)
    local header = W:WindowHeader(frame, { icon = ns.ICON, title = L.HISTORY_TITLE, version = ns.VERSION })
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if ns.WindowAppearance:CanMove() then frame:StartMoving() end
    end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local settings = W:Button(header, L.HISTORY_SETTINGS, function()
        ns.Settings:OpenSettings()
    end)
    settings:SetWidth(100)
    settings:SetPoint("RIGHT", header.close, "LEFT", -4, 0)
    self.tab = "runs"
    self.tabEntries = {}
    local tabs = W:Segmented(frame, { L.HISTORY_RUNS, L.HISTORY_PERSONAL }, { "runs", "personal" },
        function() return self.tab end, function(tab) self:SelectTab(tab) end, true)
    tabs:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 12, -4)
    tabs:SetWidth(216)
    tabs:Refresh()
    local search = W:EditBox(frame, L.HISTORY_SEARCH)
    search:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 12, -43)
    search:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -100, -43)
    search:SetMaxLetters(120)
    search:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    search:SetScript("OnEscapePressed", function(box)
        if box:GetText() ~= "" then box:SetText("") else box:ClearFocus() end
    end)
    search:HookScript("OnTextChanged", function(box)
        local hasSearch = box:GetText():find("%S") ~= nil
        if hasSearch and not self.hasSearch then
            self.beforeSearch, self.entryBeforeSearch = self.selected, self.tab == "runs" and self.entry or self.tabEntries.runs
        elseif not hasSearch and self.hasSearch then
            self.selected = self.beforeSearch
            if self.tab == "runs" then self.entry = self.entryBeforeSearch
            else self.tabEntries.runs = self.entryBeforeSearch end
        end
        self.hasSearch = hasSearch
        self.clear:SetEnabled(hasSearch)
        self:Refresh(true, true)
    end)
    local clear = W:Button(frame, L.HISTORY_CLEAR, function()
        search:SetText("")
        search:SetFocus()
    end)
    clear:SetWidth(78)
    clear:SetPoint("LEFT", search, "RIGHT", 8, 0)
    clear:Disable()
    self.search, self.clear = search, clear

    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, CONTENT_TOP + 9)
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(192)
    T:SidebarSurface(sidebar)
    self.sidebar = sidebar
    self.tabs = tabs
    self.runScroll, self.runBody = Scroll(sidebar, 8, -6, -15, 7)
    self.currentLabel = Text(self.runBody, 11, T.accent)
    self.archiveLabel = Text(self.runBody, 11, T.brass)

    self.heading = Text(frame, 14, T.text)
    self.heading:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 13, -9)
    self.heading:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, CONTENT_TOP)
    self.meta = Text(frame, 11, T.muted)
    self.meta:SetPoint("TOPLEFT", self.heading, "BOTTOMLEFT", 0, -3)
    self.itemScroll, self.itemBody = Scroll(frame, 205, LIST_TOP, -20, 11)
    self.empty = Text(self.itemBody, 12, T.muted)
    self.empty:SetPoint("TOPLEFT", 0, -5)
    self.empty:SetPoint("TOPRIGHT", -2, -5)
    local details = CreateFrame("Frame", nil, self.itemBody)
    local accent = details:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("BOTTOMLEFT")
    accent:SetWidth(1)
    Sintezza_Theme:Tint(accent, "SetColorTexture", T.line)
    self.playerDetails = details
    self.noPlayers = Text(details, 11, T.muted)
    self.noPlayers:SetText(L.HISTORY_UNKNOWN)
    self.noPlayers:Hide()

    local stripe = CreateFrame("Frame", nil, details)
    stripe:SetHeight(PLAYER_HEIGHT)
    local who = Text(stripe, 11, T.muted)
    who:SetPoint("LEFT", 10, 0)
    who:SetText(L.HISTORY_PLAYER)
    local what = Text(stripe, 11, T.muted)
    what:SetPoint("LEFT", stripe, "RIGHT", -138, 0)
    what:SetText(L.HISTORY_CHOICE)
    local score = Text(stripe, 11, T.muted, "RIGHT")
    score:SetPoint("RIGHT", -13, 0)
    score:SetText(L.HISTORY_SCORE)
    self.playerHeader = stripe
    self.runRows, self.itemRows, self.playerRows = {}, {}, {}
    self.frame = frame
    frame:HookScript("OnHide", function()
        frame:StopMovingOrSizing()
        search:ClearFocus()
    end)
    table.insert(UISpecialFrames, frame:GetName())
end

function H:SelectTab(tab)
    if tab == self.tab then return end
    self.tabEntries[self.tab] = self.entry
    self.tab, self.entry = tab, self.tabEntries[tab]
    local personal = tab == "personal"
    self.sidebar:SetShown(not personal)
    self.heading:SetPoint("TOPLEFT", self.frame, "TOPLEFT", personal and 13 or 205, CONTENT_TOP)
    self.itemScroll:SetPoint("TOPLEFT", self.frame, "TOPLEFT", personal and 13 or 205, LIST_TOP)
    self:Refresh(false, true)
end

local function PlaceGroupLabel(label, parent, y, text)
    label:SetText(text)
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 7, -y)
    label:Show()
    return y + 18
end

function H:RefreshRunList(groups, query, resetScroll)
    local selected
    self.currentLabel:Hide()
    self.archiveLabel:Hide()
    local y, laidOutArchive = 2, false
    for i, group in ipairs(groups) do
        if group.key == self.selected then selected = group end
        if group.active then
            y = PlaceGroupLabel(self.currentLabel, self.runBody, y, L.HISTORY_CURRENT)
        elseif not laidOutArchive then
            y = PlaceGroupLabel(self.archiveLabel, self.runBody, y + 5, L.HISTORY_ARCHIVE)
            laidOutArchive = true
        end
        local row = self.runRows[i]
        if not row then
            row = CreateRunRow(self.runBody)
            self.runRows[i] = row
        end
        row.groupKey = group.key
        row.text:SetText(group.name)
        local detail = TimeLabel(group.run)
        if group.active and self.insideRunID ~= group.key then detail = L.HISTORY_PAUSED end
        if query ~= "" or detail == "" then
            detail = detail == "" and RollCount(#group.entries) or detail .. " · " .. RollCount(#group.entries)
        end
        row.meta:SetText(detail)
        Sintezza_Theme:Tint(row.meta, "SetTextColor", group.active and T.accent or T.muted)
        y = LayoutRow(row, self.runBody, y, 43)
    end
    selected = selected or groups[1]
    self.selected = selected and selected.key
    for i, row in ipairs(self.runRows) do
        row:SetShown(i <= #groups)
        row:SetSelected(i <= #groups and row.groupKey == self.selected)
    end
    self.runBody:SetHeight(math.max(1, y))
    if resetScroll then self.runScroll:SetVerticalScroll(0) end
    self.runScroll:RefreshRange()
    return selected
end

function H:Refresh(useMatch, resetScroll)
    if not self.frame then return end
    local text = self.search:GetText()
    local personal = self.tab == "personal"
    local entries, query, run, empty, attempts
    if personal then
        entries, query = self:FindPersonalLoot(text)
        attempts = self:GetPersonalAttempts()
        local name = ns.RosterInspector:GetUnitNames("player")
        self.heading:SetText(name or L.HISTORY_PERSONAL)
        self.meta:SetText(RollCount(#entries))
        empty = query ~= "" and L.HISTORY_NO_MATCH or L.HISTORY_PERSONAL_EMPTY
    else
        local groups
        groups, query = self:FindRuns(text)
        local selected = self:RefreshRunList(groups, query, resetScroll and useMatch)
        entries = selected and selected.entries or {}
        run = selected and selected.run
        if useMatch and query ~= "" then self.entry = selected and selected.playerMatch end
        self.heading:SetText(selected and selected.name or "")
        local count = RollCount(#entries)
        local dateRange = TimeLabel(run)
        self.meta:SetText(selected and (dateRange == "" and count or dateRange .. " · " .. count) or "")
        empty = query ~= "" and #groups == 0 and L.HISTORY_NO_MATCH or L.HISTORY_EMPTY
    end
    self.empty:SetText(empty)
    self.empty:SetShown(#entries == 0)
    self.playerDetails:Hide()
    self.playerHeader:Hide()
    self.noPlayers:Hide()
    for _, row in ipairs(self.playerRows) do row:Hide() end
    local y = 0
    for i, entry in ipairs(entries) do
        local row = self.itemRows[i]
        if not row then
            row = CreateItemRow(self.itemBody)
            self.itemRows[i] = row
        end
        row.entry = entry
        local open = self.entry == entry
        local r, g, b = ns.GetItemQualityColor(entry.quality)
        row.icon:SetTexture(entry.icon or 134400)
        row.border:SetBackdropBorderColor(r, g, b, .9)
        row.name:SetText(self:GetItemName(entry))
        row.name:SetTextColor(r, g, b, 1)
        local stamp = entry.time and date(run and "%H:%M" or "%d.%m %H:%M", entry.time) or ""
        local context = personal and self:GetRunName(entry) or self:GetSourceName(entry)
        if context then stamp = stamp == "" and context or stamp .. " · " .. context end
        local attempt = attempts and attempts[entry]
        if attempt then stamp = stamp .. " · " .. L.HISTORY_WON_ATTEMPT:format(attempt) end
        row.meta:SetText(stamp)
        if personal then
            ShowPersonalOutcome(row, entry)
        else
            local winner = entry.winner
            row.outcomeIcon:Hide()
            row.outcomeHover:Hide()
            local outcome = winner and (winner.isSelf and L.HISTORY_YOU_WON or winner.name or L.HISTORY_UNKNOWN)
                or (entry.allPassed and L.WINNER_ALL_PASSED or L.HISTORY_UNKNOWN)
            local class = self:GetWinnerClass(entry)
            if class then outcome = "|c" .. ns.RosterInspector:GetClassColorHex(class) .. outcome .. "|r" end
            row.outcome:SetText(outcome)
        end
        row.chevron:SetExpanded(open)
        row.band:SetShown(i % 2 == 0)
        y = LayoutRow(row, self.itemBody, y, ITEM_HEIGHT)
        if open then y = self:ShowPlayers(entry, y, query) end
    end
    for i = #entries + 1, #self.itemRows do self.itemRows[i]:Hide() end
    self.itemBody:SetHeight(math.max(26, y))
    if resetScroll then self.itemScroll:SetVerticalScroll(0) end
    self.itemScroll:RefreshRange()
end

function H:Open()
    if not self.frame then self:Create() end
    ns.WindowAppearance:Bind(self.frame, { resize = { minWidth = 680, minHeight = 370, maxWidth = 1320, maxHeight = 940 } })
    self:Refresh()
    self.frame:Show()
    self.frame:Raise()
end

function H:Toggle()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Open()
    end
end
