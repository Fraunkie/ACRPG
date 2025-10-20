if Debug and Debug.beginFile then Debug.beginFile("SpiritDrive.lua") end
--==================================================
-- SpiritDrive.lua
-- "Rage meter" that fills from combat and drains out of combat.
-- • Add(pid, amount)
-- • Get(pid)
-- • Set(pid, value)
-- • IsFull(pid)
-- Drains automatically when not in combat.
--==================================================

if not SpiritDrive then SpiritDrive = {} end
_G.SpiritDrive = SpiritDrive

do
    local CU = _G.CoreUtils or {}
    local MAX_SPIRIT = (GameBalance and GameBalance.SPIRIT_DRIVE_MAX) or 100
    local DECAY_RATE = (GameBalance and GameBalance.SPIRIT_DRIVE_DECAY_RATE) or 1
    local DECAY_TICK = 1.0

    local val = {}  -- pid -> current spirit
    local lastCombat = {}

    local function inCombat(pid)
        if _G.CombatEventsBridge and CombatEventsBridge.IsInCombat then
            return CombatEventsBridge.IsInCombat(pid)
        end
        local t = lastCombat[pid]
        if not t or not os or not os.clock then return false end
        return (os.clock() - t) < 6
    end

    local function clamp(v)
        if v < 0 then return 0 end
        if v > MAX_SPIRIT then return MAX_SPIRIT end
        return v
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function SpiritDrive.Get(pid)
        return val[pid] or 0
    end

    function SpiritDrive.Set(pid, amount)
        val[pid] = clamp(amount or 0)
        if _G.SpiritPowerLabelBridge and SpiritPowerLabelBridge.Update then
            SpiritPowerLabelBridge.Update(pid, val[pid], MAX_SPIRIT)
        end
    end

    function SpiritDrive.Add(pid, amount)
        if not pid then return end
        local v = val[pid] or 0
        v = clamp(v + (amount or 0))
        val[pid] = v
        lastCombat[pid] = os.clock()
        if _G.SpiritPowerLabelBridge and SpiritPowerLabelBridge.Update then
            SpiritPowerLabelBridge.Update(pid, v, MAX_SPIRIT)
        end
    end

    function SpiritDrive.IsFull(pid)
        return (val[pid] or 0) >= MAX_SPIRIT
    end

    --------------------------------------------------
    -- Decay handler
    --------------------------------------------------
    local function tick()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                if not inCombat(pid) then
                    local v = val[pid] or 0
                    if v > 0 then
                        v = clamp(v - DECAY_RATE)
                        val[pid] = v
                        if _G.SpiritPowerLabelBridge and SpiritPowerLabelBridge.Update then
                            SpiritPowerLabelBridge.Update(pid, v, MAX_SPIRIT)
                        end
                    end
                end
            end
        end
    end

    OnInit.final(function()
        local t = CreateTimer()
        TimerStart(t, DECAY_TICK, true, tick)
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SpiritDrive")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
