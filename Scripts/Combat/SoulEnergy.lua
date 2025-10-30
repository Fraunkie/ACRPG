if Debug and Debug.beginFile then Debug.beginFile("SoulEnergy.lua") end
--==================================================
-- SoulEnergy.lua (Adapter)
-- Thin UI/bridge over SoulEnergyLogic (custom XP system).
-- • NO spending API (progression-only).
-- • Delegates all math/state to SoulEnergyLogic.
-- • Keeps UI labels in sync and listens to ProcBus events.
--==================================================

if not SoulEnergy then SoulEnergy = {} end
_G.SoulEnergy = SoulEnergy

do
    --------------------------------------------------
    -- Local helpers
    --------------------------------------------------
    local function dprint(msg)
        if _G.DevMode and DevMode.IsOn and DevMode.IsOn(0) then
            print("[SoulEnergy] " .. tostring(msg))
        end
    end

    -- Be tolerant to whichever bridge exists right now.
    local function setLevelLabel(pid, lvl)
        local B = _G.SpiritPowerLabelBridge
        if B and B.SetSoulLevel then
            pcall(B.SetSoulLevel, pid, lvl or 1)
        elseif B and B.SetSoul then
            -- legacy: single value label; show XP total if that's what your UI expects
            pcall(B.SetSoul, pid, lvl or 1)
        end
    end

    local function setXpLabel(pid, xp)
        local B = _G.SpiritPowerLabelBridge
        if B and B.SetSoul then
            pcall(B.SetSoul, pid, xp or 0)
        end
    end

    local function pingGain(pid, delta)
        local B = _G.SpiritPowerLabelBridge
        if B and B.PingSoul then
            pcall(B.PingSoul, pid, delta or 0)
        end
    end

    local function logic()
        return _G.SoulEnergyLogic
    end

    --------------------------------------------------
    -- Public API (read + award)
    --------------------------------------------------
    function SoulEnergy.GetXp(pid)
        local L = logic()
        if L and L.GetXp then return L.GetXp(pid) end
        return 0
    end

    function SoulEnergy.GetLevel(pid)
        local L = logic()
        if L and L.GetLevel then return L.GetLevel(pid) end
        return 1
    end

    -- Award XP (positive or negative); UI will auto-update.
    -- reason/meta are optional passthrough for debugging/FX.
    function SoulEnergy.AddXp(pid, delta, reason, meta)
        local L = logic()
        if not (L and L.AddXp) then return SoulEnergy.GetXp(pid) end

        local beforeXp = L.GetXP(pid)
        local retXp = L.Add(pid, delta or 0, reason, meta)

        -- Small visual ping for gains
        if (delta or 0) > 0 then
            pingGain(pid, delta or 0)
        end
        -- Labels are also updated by our event listeners below; update proactively too:
        setXpLabel(pid, retXp)
        setLevelLabel(pid, SoulEnergy.GetLevel(pid))
        dprint("AddXp pid=" .. tostring(pid) .. " delta=" .. tostring(delta or 0) ..
               " -> " .. tostring(beforeXp) .. " => " .. tostring(retXp))
        return retXp
    end

    -- Optional: set absolute XP (admin/dev). Use sparingly.
    function SoulEnergy.SetXp(pid, value)
        local L = logic()
        if not (L and L.SetXp) then return SoulEnergy.GetXp(pid) end
        local xp = L.SetXp(pid, value or 0)
        setXpLabel(pid, xp)
        setLevelLabel(pid, SoulEnergy.GetLevel(pid))
        dprint("SetXp pid=" .. tostring(pid) .. " xp=" .. tostring(xp))
        return xp
    end

    --------------------------------------------------
    -- Event wiring: mirror logic → UI
    --------------------------------------------------
    local function wireEvents()
        local PB = rawget(_G, "ProcBus")
        if not (PB and PB.On) then return end

        PB.On("OnSoulXpChanged", function(e)
            if not e or e.pid == nil then return end
            setXpLabel(e.pid, e.xp or 0)
            -- No ping here; pings are only for deltas/gains.
        end)

        PB.On("OnSoulLevelUp", function(e)
            if not e or e.pid == nil then return end
            setLevelLabel(e.pid, e.level or 1)
            -- Optional: celebratory ping on level-up (small)
            pingGain(e.pid, 0)
        end)
    end

    --------------------------------------------------
    -- Init: seed labels for all playing users
    --------------------------------------------------
    OnInit.final(function()
        wireEvents()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                setXpLabel(pid, SoulEnergy.GetXp(pid))
                setLevelLabel(pid, SoulEnergy.GetLevel(pid))
            end
        end
        dprint("adapter ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SoulEnergyAdapter")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
