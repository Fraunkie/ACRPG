if Debug and Debug.beginFile then Debug.beginFile("SoulEnergy.lua") end
--==================================================
-- SoulEnergy.lua
-- Per-player Soul Energy store and events.
-- • Add(pid, amount)
-- • Get(pid)
-- • Set(pid, value)
-- • OnKill handled by CombatEventsBridge via SoulEnergyLogic
-- Emits:
--  - SoulEnergyChanged { pid, value, delta }
--  - SoulEnergyGained  { pid, gain, total }
--==================================================

if not SoulEnergy then SoulEnergy = {} end
_G.SoulEnergy = SoulEnergy

do
    local VAL = {}  -- pid -> total soul xp

    local function clampNonNeg(n)
        if not n or n < 0 then return 0 end
        return n
    end

    local function updateLabel(pid)
        if _G.SpiritPowerLabelBridge and SpiritPowerLabelBridge.UpdateSoul then
            local v = VAL[pid] or 0
            pcall(SpiritPowerLabelBridge.UpdateSoul, pid, v)
        end
    end

    local function emit(name, payload)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then
            PB.Emit(name, payload)
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function SoulEnergy.Get(pid)
        return VAL[pid] or 0
    end

    function SoulEnergy.Set(pid, value)
        local old = VAL[pid] or 0
        local v = clampNonNeg(value)
        VAL[pid] = v
        updateLabel(pid)
        emit("SoulEnergyChanged", { pid = pid, value = v, delta = v - old })
    end

    function SoulEnergy.Add(pid, amount)
        if not pid then return end
        local add = clampNonNeg(amount)
        if add == 0 then return end
        local v = (VAL[pid] or 0) + add
        VAL[pid] = v
        updateLabel(pid)
        emit("SoulEnergyGained",  { pid = pid, gain = add, total = v })
        emit("SoulEnergyChanged", { pid = pid, value = v,  delta = add })
    end

    --------------------------------------------------
    -- Optional: convenience for kill handler
    --------------------------------------------------
    function SoulEnergy.RewardKill(killer, dead)
        if not _G.SoulEnergyLogic or not SoulEnergyLogic.GetReward then return end
        if not killer or GetUnitTypeId(killer) == 0 or not dead or GetUnitTypeId(dead) == 0 then return end
        local pid = GetPlayerId(GetOwningPlayer(killer))
        if pid == nil then return end
        local base = SoulEnergyLogic.GetReward(GetUnitTypeId(dead)) or 0
        if base > 0 then
            SoulEnergy.Add(pid, base)
        end
    end

    OnInit.final(function()
        -- Optional: wire to ProcBus if someone emits explicit rewards
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("SoulReward", function(e)
                if not e then return end
                if e.pid and e.amount then SoulEnergy.Add(e.pid, e.amount) end
            end)
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SoulEnergy")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
