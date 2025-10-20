if Debug and Debug.beginFile then Debug.beginFile("SoulEnergyLogic.lua") end
--==================================================
-- SoulEnergyLogic.lua
-- Reward lookup and simple XP math for SoulEnergy.
-- • GetReward(fourId) -> base reward for a killed unit type
--==================================================

if not SoulEnergyLogic then SoulEnergyLogic = {} end
_G.SoulEnergyLogic = SoulEnergyLogic

do
    local function dprint(msg)
        local DM = rawget(_G, "DevMode")
        if DM and DM.IsOn and DM.IsOn(0) then print("[SoulLogic] " .. tostring(msg)) end
    end

    local function fromBalance(four)
        if not _G.GameBalance then return 0 end
        local t = GameBalance.SOUL_REWARD_BY_FOUR
        if type(t) == "table" then
            local v = t[four]
            if type(v) == "number" and v > 0 then return v end
        end
        if type(GameBalance.XP_PER_KILL_BASE) == "number" and GameBalance.XP_PER_KILL_BASE > 0 then
            return GameBalance.XP_PER_KILL_BASE
        end
        return 0
    end

    local function fromHFIL(four)
        if _G.HFILUnitConfig and HFILUnitConfig.GetByTypeId then
            local row = HFILUnitConfig.GetByTypeId(four)
            if row and type(row.baseSoul) == "number" then
                return math.max(0, row.baseSoul)
            end
        end
        if _G.HFIL_UnitConfig_Dev and HFIL_UnitConfig_Dev.GetByTypeId then
            local row = HFIL_UnitConfig_Dev.GetByTypeId(four)
            if row and type(row.baseSoul) == "number" then
                return math.max(0, row.baseSoul)
            end
        end
        return 0
    end

    function SoulEnergyLogic.GetReward(four)
        if type(four) ~= "number" then return 0 end
        local v = fromHFIL(four)
        if v > 0 then return v end
        v = fromBalance(four)
        if v > 0 then return v end
        return 0
    end

    function SoulEnergyLogic.XpToLevel(xp)
        if type(xp) ~= "number" or xp < 0 then return 1 end
        return 1 + math.floor(xp / 100)
    end

    function SoulEnergyLogic.LevelToNext(level)
        if type(level) ~= "number" or level < 1 then return 100 end
        return 100
    end

    OnInit.final(function()
        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SoulEnergyLogic")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
