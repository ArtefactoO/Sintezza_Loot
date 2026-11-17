local addon, ns = ...
local api = _G.Sintezza_PerfAPI
if type(api) ~= "table" or api.version ~= 1 then return end
local module = api:RegisterModule(addon, "loot", { title = "Loot history and rolls", titleRu = "История и розыгрыши" })
if not module then return end
local call = api:RegisterPoint(module, "attempts", { title = "Calculate personal attempts", titleRu = "Расчет личных попыток", memory = true })
local counter = api:RegisterPoint(module, "evaluate", { kind = "counter", title = "Roll evaluations", titleRu = "Проверки розыгрышей" })
local bridge = {}
ns.PerfBridge = bridge
function bridge.Count(key)
    if key == "evaluate" and counter then api:Count(counter) end
end
local owner = ns.History
if call and owner and type(owner.GetPersonalAttempts) == "function" then
    local original = owner.GetPersonalAttempts
    owner.GetPersonalAttempts = function(...)
        if not api:IsActive(call) then return original(...) end
        if issecretvalue then
            for i = 1, select("#", ...) do
                if issecretvalue(select(i, ...)) then return original(...) end
            end
        end
        return api:Call(call, original, ...)
    end
end
