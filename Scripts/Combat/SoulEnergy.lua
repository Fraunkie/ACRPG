if Debug and Debug.beginFile then Debug.beginFile("SoulEnergy.lua") end
--==================================================
-- SoulEnergy.lua (adapter over SoulEnergyLogic)
--==================================================

if not SoulEnergy then SoulEnergy = {} end
_G.SoulEnergy = SoulEnergy

do
    --------------------------------------------------
    -- helpers
    --------------------------------------------------
    local function setLevelLabel(pid, lvl)
        local B = _G.SpiritPowerLabelBridge
        if B and B.SetSoulLevel then
            pcall(B.SetSoulLevel, pid, lvl or 1)
        elseif B and B.SetSoul then
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
    -- read
    --------------------------------------------------
    function SoulEnergy.GetXp(pid)
        local L = logic()
        if L and L.GetXP then return L.GetXP(pid) end
        if L and L.Get then return L.Get(pid) end
        return 0
    end

    function SoulEnergy.GetLevel(pid)
        local L = logic()
        if L and L.GetLevel then return L.GetLevel(pid) end
        return 1
    end

    -- next level total (for UI)
    function SoulEnergy.GetNextXP(pid)
        local lvl = SoulEnergy.GetLevel(pid)
        local L = logic()
        if L and L.LevelToTotalXp then
            return L.LevelToTotalXp(lvl + 1)
        end
        return 0
    end

    --------------------------------------------------
    -- write
    --------------------------------------------------
    function SoulEnergy.AddXp(pid, delta, reason, meta)
        local L = logic()
        if not L then
            return SoulEnergy.GetXp(pid)
        end

        -- LOGIC HAS: Add(...)  (not AddXp)
        local before = SoulEnergy.GetXp(pid)
        local ret

        if L.Add then
            ret = L.Add(pid, delta or 0, reason, meta)
        elseif L.AddXp then
            -- fallback in case logic ever exposes AddXp
            ret = L.AddXp(pid, delta or 0, reason, meta)
        else
            return before
        end

        if (delta or 0) > 0 then
            pingGain(pid, delta or 0)
        end

        setXpLabel(pid, ret)
        setLevelLabel(pid, SoulEnergy.GetLevel(pid))

        DisplayTextToPlayer(Player(pid), 0, 0,
            "Soul XP: " .. tostring(ret) .. " / " .. tostring(SoulEnergy.GetNextXP(pid)) ..
            "  —  Soul Level: " .. tostring(SoulEnergy.GetLevel(pid)))

        return ret
    end

    function SoulEnergy.SetXp(pid, value)
        local L = logic()
        if not (L and L.Set) and not (L and L.SetXp) then
            return SoulEnergy.GetXp(pid)
        end

        local xp
        if L.Set then
            xp = L.Set(pid, value or 0)
        else
            xp = L.SetXp(pid, value or 0)
        end

        setXpLabel(pid, xp)
        setLevelLabel(pid, SoulEnergy.GetLevel(pid))
        return xp
    end

    --------------------------------------------------
    -- init
    --------------------------------------------------
    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                setXpLabel(pid, SoulEnergy.GetXp(pid))
                setLevelLabel(pid, SoulEnergy.GetLevel(pid))
            end
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SoulEnergyAdapter")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
