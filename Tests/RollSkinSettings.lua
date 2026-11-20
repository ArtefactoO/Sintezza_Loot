local function CheckProfile(saved, expected)
    local eventFrame = {}
    function eventFrame:RegisterEvent() end
    function eventFrame:SetScript(_, callback) self.onEvent = callback end

    local env = setmetatable({
        CreateFrame = function() return eventFrame end,
        GetBuildInfo = function() return "1.60.1", "70959", "", 16001 end,
        Sintezza_Theme = { icons = {} },
        Sintezza_LootDB = saved,
        SlashCmdList = {},
    }, { __index = _G })
    env._G = env

    local valueAtInit
    local ns = {
        L = {},
        Launcher = { RegisterMinimap = function() end },
    }
    ns.RollEffects = {
        Init = function() valueAtInit = ns.db.skinGroupLoot end,
    }
    setfenv(assert(loadfile(ADDON_ROOT .. "/Core.lua")), env)("Sintezza_Loot", ns)
    eventFrame.onEvent(eventFrame, "ADDON_LOADED", "Sintezza_Loot")
    assert(valueAtInit == expected and ns.db.skinGroupLoot == expected,
        "Unexpected roll skin preference at module initialization")
    ns:InitDB()
    assert(ns.db == env.Sintezza_LootDB and ns.db.skinGroupLoot == expected)
    if saved then assert(ns.db == saved) end
end

CheckProfile(nil, true)
CheckProfile({ groupLootSkinOptInMigrated = true }, true)
CheckProfile({ skinGroupLoot = false, groupLootSkinOptInMigrated = true }, false)
CheckProfile({ skinGroupLoot = true, groupLootSkinOptInMigrated = true }, true)
CheckProfile({ skinGroupLoot = false }, false)
CheckProfile({ skinGroupLoot = true }, true)
print("PASS: roll skin defaults on and saved on/off choices survive initialization")
