if Debug and Debug.beginFile then Debug.beginFile("LootSystem_Bridge.lua") end
--==================================================
-- LootSystem_Bridge.lua
-- Bridges CombatEventsBridge kill events into LootSystem.
-- • Listens to ProcBus "OnKill"
-- • Calls LootSystem.OnKill(killer, dead) if present
--==================================================

do
    local function valid(u) return u ~= nil and GetUnitTypeId(u) ~= 0 end

    local function onKill(e)
        if not e then return end
        local killer = e.source
        local dead   = e.target
        if not valid(dead) then return end
        if _G.LootSystem and LootSystem.OnKill then
            -- Safe-call to avoid cascading errors
            pcall(LootSystem.OnKill, killer, dead)
        end
        -- Optional: notify chest systems if they hook kills
        if _G.LootChestSystem and LootChestSystem.OnKill then
            pcall(LootChestSystem.OnKill, killer, dead)
        end
    end

    OnInit.final(function()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnKill", onKill)
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("LootSystem_Bridge")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
