--if Debug and Debug.beginFile then Debug.beginFile("SoulEnergy.lua") end
--==================================================
-- SoulEnergy.lua  (Adapter → SoulEnergyLogic)
--==================================================

if not SoulEnergy then SoulEnergy = {} end
_G.SoulEnergy = SoulEnergy

do

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
    -- Public API
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

    function SoulEnergy.AddXp(pid, delta, reason, meta)
        local L = logic()
        if not L then return SoulEnergy.GetXp(pid) end

        -- prefer Add if present
        local addFn = L.Add or L.AddXp
        if not addFn then
            return SoulEnergy.GetXp(pid)
        end

        local beforeXp = (L.GetXP and L.GetXP(pid)) or (L.Get and L.Get(pid)) or 0
        local retXp = addFn(pid, delta or 0, reason, meta)

        if (delta or 0) > 0 then
            pingGain(pid, delta or 0)
        end

        setXpLabel(pid, retXp)
        setLevelLabel(pid, SoulEnergy.GetLevel(pid))


        return retXp
    end

    function SoulEnergy.SetXp(pid, value)
        local L = logic()
        if not L then return SoulEnergy.GetXp(pid) end
        local setFn = L.Set or L.SetXp
        if not setFn then return SoulEnergy.GetXp(pid) end
        local xp = setFn(pid, value or 0)
        setXpLabel(pid, xp)
        setLevelLabel(pid, SoulEnergy.GetLevel(pid))
        return xp
    end

    function SoulEnergy.GetNextXP(pid)
        local L = logic()
        if not L then return 0 end
        local lvl = (L.GetLevel and L.GetLevel(pid)) or 1
        local nxt = (L.LevelToTotalXp and L.LevelToTotalXp(lvl + 1)) or 0
        return nxt
    end

    --------------------------------------------------
    -- Events
    --------------------------------------------------
    local function wireEvents()
        local PB = rawget(_G, "ProcBus")
        if not (PB and PB.On) then return end

        PB.On("OnSoulXpChanged", function(e)
            if not e or e.pid == nil then return end
            setXpLabel(e.pid, e.xp or 0)
        end)

        PB.On("OnSoulLevelUp", function(e)
            if not e or e.pid == nil then return end
            setLevelLabel(e.pid, e.level or 1)
            pingGain(e.pid, 0)
        end)
    end

    OnInit.final(function()
        wireEvents()
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

--if Debug and Debug.endFile then Debug.endFile() end
