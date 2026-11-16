local addonName, ns = ...
local DataTracker = ns.DataTracker

local MultiItemManager = {}
ns.MultiItemManager = MultiItemManager

local NUM_GROUP_LOOT_FRAMES = 4
local hookedFrames = setmetatable({}, { __mode = "k" })

local function GetGroupLootFrameForRollID(rollID)
    for i = 1, NUM_GROUP_LOOT_FRAMES do
        local glf = _G["GroupLootFrame" .. i]
        if glf and glf:IsShown() and not ns.IsSecretValue(glf.rollID) and glf.rollID == rollID then
            return glf
        end
    end
    return nil
end

local function GetAnyShownGroupLootFrame()
    for i = 1, NUM_GROUP_LOOT_FRAMES do
        local glf = _G["GroupLootFrame" .. i]
        if glf and glf:IsShown() then
            return glf
        end
    end
    return nil
end

function MultiItemManager:UpdateAnchoring()
    local tracker = ns.RollTrackerFrame and ns.RollTrackerFrame.frame
    if not tracker or tracker.dragging then return end

    local side = ns.db and ns.db.anchorSide or "RIGHT"
    local session = DataTracker:GetCurrentRollSession()

    if side == "FREE" and ns.db.freePosition then
        local pos = ns.db.freePosition
        tracker:ClearAllPoints()
        tracker:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 220, pos.y or 0)
        return
    end

    -- Find the GroupLootFrame matching the current rollID, or fallback to any shown GroupLootFrame / UIParent
    local targetGLF = (session and GetGroupLootFrameForRollID(session.rollID)) or GetAnyShownGroupLootFrame()

    tracker:ClearAllPoints()
    if targetGLF and targetGLF:IsShown() and targetGLF:GetNumPoints() > 0 then
        if side == "LEFT" then
            tracker:SetPoint("BOTTOMRIGHT", targetGLF, "BOTTOMLEFT", -12, 0)
        else
            tracker:SetPoint("BOTTOMLEFT", targetGLF, "BOTTOMRIGHT", 12, 0)
        end
    else
        -- DefaultGroupLootContainer / GroupLootFrame1 position when no real GroupLootFrame is currently visible (e.g. solo /sloot test)
        if side == "LEFT" then
            tracker:SetPoint("CENTER", UIParent, "CENTER", -220, -40)
        else
            tracker:SetPoint("CENTER", UIParent, "CENTER", 220, -40)
        end
    end
end

function MultiItemManager:HookGroupLootFrames()
    for i = 1, NUM_GROUP_LOOT_FRAMES do
        local glf = _G["GroupLootFrame" .. i]
        if glf and not hookedFrames[glf] then
            hookedFrames[glf] = true

            glf:HookScript("OnShow", function(self)
                MultiItemManager:UpdateAnchoring()
            end)

            glf:HookScript("OnHide", function(self)
                MultiItemManager:UpdateAnchoring()
            end)

            glf:HookScript("OnEnter", function(self)
                local rollID = self.rollID
                if ns.db and ns.db.autoSwitchOnHover and not ns.IsSecretValue(rollID) and rollID then
                    DataTracker:SetCurrentRollID(rollID, false)
                end
            end)
        end
    end
end

function MultiItemManager:Init()
    self:HookGroupLootFrames()
    self:UpdateAnchoring()

    ns:RegisterEvent("UI_SCALE_CHANGED", function()
        self:UpdateAnchoring()
    end)
    ns:RegisterEvent("DISPLAY_SIZE_CHANGED", function()
        self:UpdateAnchoring()
    end)
end
