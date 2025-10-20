if Debug and Debug.beginFile then Debug.beginFile("SoulEnergy.lua") end
--==================================================
-- SoulEnergy.lua
-- Thin adapter over SoulEnergyLogic for UI bridges.
-- • Updates SpiritPowerLabelBridge on changes
-- • Listens to ProcBus to stay in sync
--==================================================

if not SoulEnergy then SoulEnergy = {} end
_G.SoulEnergy = SoulEnergy

do
    local function dprint(s)
        if _G.DevMode and DevMode.IsOn and DevMode.IsOn() then
            print("[SoulAdapter] " .. tostring(s))
        end
    end

    local function setLabel(pid, value)
        if _G.SpiritPowerLabelBridge and SpiritPowerLabelBridge.SetSoul then
            pcall(SpiritPowerLabelBridge.SetSoul, pid, value or 0)
        end
    end

    local function pingLabel(pid, delta)
        if _G.SpiritPowerLabelBridge and SpiritPowerLabelBridge.PingSoul then
            pcall(SpiritPowerLabelBridge.PingSoul, pid, delta or 0)
        end
    end

    local function logicGet(pid)
        if _G.SoulEnergyLogic and SoulEnergyLogic.Get then
            return SoulEnergyLogic.Get(pid)
        end
        return 0
    end

    function SoulEnergy.Get(pid) return logicGet(pid) end

    function SoulEnergy.Set(pid, value)
        local v = value or 0
        if _G.SoulEnergyLogic and SoulEnergyLogic.Set then
            v = SoulEnergyLogic.Set(pid, v)
        end
        setLabel(pid, v)
        dprint("Set pid " .. tostring(pid) .. " = " .. tostring(v))
        return v
    end

    function SoulEnergy.Add(pid, delta)
        local v = logicGet(pid)
        if _G.SoulEnergyLogic and SoulEnergyLogic.Add then
            v = SoulEnergyLogic.Add(pid, delta or 0)
        end
        if math.abs(delta or 0) > 0 then
            pingLabel(pid, delta or 0)
        end
        setLabel(pid, v)
        dprint("Add pid " .. tostring(pid) .. " +" .. tostring(delta or 0) .. " -> " .. tostring(v))
        return v
    end

    function SoulEnergy.Spend(pid, cost)
        if _G.SoulEnergyLogic and SoulEnergyLogic.Spend then
            local ok = SoulEnergyLogic.Spend(pid, cost or 0)
            if ok then setLabel(pid, logicGet(pid)) end
            return ok
        end
        return false
    end

    function SoulEnergy.Ping(pid, amount)
        pingLabel(pid, amount or 0)
        if _G.SoulEnergyLogic and SoulEnergyLogic.Ping then
            pcall(SoulEnergyLogic.Ping, pid, amount or 0)
        end
    end

    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                setLabel(pid, logicGet(pid))
            end
        end
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnSoulChanged", function(e)
                if not e or e.pid == nil then return end
                setLabel(e.pid, e.value or 0)
            end)
            PB.On("OnSoulPing", function(e)
                if not e or e.pid == nil then return end
                pingLabel(e.pid, e.delta or 0)
            end)
        end
        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SoulEnergyAdapter")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
