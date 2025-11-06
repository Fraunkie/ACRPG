if Debug and Debug.beginFile then Debug.beginFile("Passive_SoulSpirit.lua") end
--==================================================
-- Passive_SoulSpirit.lua
-- • Gives a flat attack-speed bonus when the passive is UNLOCKED
-- • Uses the SAME style of unlock check as the Spellbook module
-- • Writes through StatSystem.ApplySource so it stacks with items
-- • Falls back to direct StatSystem.SetUnitStat if ApplySource missing
--==================================================

do
    -- CHANGE THESE TWO IF NEEDED
    local ABIL_ID     = FourCC("A000")  -- your dummy/passive ability id
    local BONUS_AS    = 4.00            -- +25% attack speed (use 2.00 for +200% test)
    local SOURCE_KEY  = "passive_soulspirit"

    -- if you want to probe:
    local DEBUG_SOULSPIRIT = true

    local function log(msg)
        if DEBUG_SOULSPIRIT then
            DisplayTextToPlayer(Player(0), 0, 0, "[SoulSpirit] " .. tostring(msg))
        end
    end

    --------------------------------------------------
    -- hero / player helpers
    --------------------------------------------------
    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function heroOf(pid)
        -- our project uses PLAYER_DATA as canon
        if _G.PLAYER_DATA and _G.PLAYER_DATA[pid] and validUnit(_G.PLAYER_DATA[pid].hero) then
            return _G.PLAYER_DATA[pid].hero
        end
        if _G.PlayerHero and validUnit(_G.PlayerHero[pid]) then
            return _G.PlayerHero[pid]
        end
        return nil
    end

    local function getRole(pid)
        local pd = _G.PLAYER_DATA and _G.PLAYER_DATA[pid]
        if pd and pd.role and pd.role ~= "" then
            return pd.role
        end
        local GB = rawget(_G, "GameBalance")
        if GB and GB.GetRoleDefault then
            return GB.GetRoleDefault()
        end
        return "DPS"
    end

    local function getSoulLevel(pid)
        if _G.SoulEnergy and SoulEnergy.GetLevel then
            local ok, lv = pcall(SoulEnergy.GetLevel, pid)
            if ok and type(lv) == "number" then
                return lv
            end
        end
        local pd = _G.PLAYER_DATA and _G.PLAYER_DATA[pid]
        if pd and type(pd.soulLevel) == "number" then
            return pd.soulLevel
        end
        return 1
    end

    local function getPowerLevel(pid)
        local pd = _G.PLAYER_DATA and _G.PLAYER_DATA[pid]
        if pd and type(pd.powerLevel) == "number" then
            return pd.powerLevel
        end
        return 0
    end

    local function hasFamily(pid, fam)
        if not fam or fam == "" then
            return true
        end
        local pd = _G.PLAYER_DATA and _G.PLAYER_DATA[pid]
        if not pd then
            return false
        end
        if pd.families and pd.families[fam] then
            return true
        end
        if pd.chargedFamilies and pd.chargedFamilies[fam] then
            return true
        end
        if pd.lastFamilyKey == fam then
            return true
        end
        return false
    end

    --------------------------------------------------
    -- the important bit: "do we actually have this spell unlocked?"
    -- this mirrors what your Spellbook module does:
    --   GameBalance.GetSpellUnlocksByUnit()
    --   -> list for this unitType
    --   -> match entry.abil
    --   -> check need.sl_min, need.pl_min, need.role, need.family
    --------------------------------------------------
    local function isSoulSpiritUnlocked(pid, u)
        if not validUnit(u) then
            return false
        end

        -- if the unit literally has the ability, we accept it right away
        if GetUnitAbilityLevel(u, ABIL_ID) > 0 then
            return true
        end

        local GB = rawget(_G, "GameBalance")
        if not GB then
            return false
        end

        -- prefer the newer per-unit unlocks (this is what your spellbook was using)
        local allByUnit = (GB.GetSpellUnlocksByUnit and GB.GetSpellUnlocksByUnit()) or GB.SPELL_UNLOCKS_BY_UNIT or nil
        local unitType  = GetUnitTypeId(u)

        if allByUnit and allByUnit[unitType] then
            local list = allByUnit[unitType]
            local mySL  = getSoulLevel(pid)
            local myPL  = getPowerLevel(pid)
            local myRole= getRole(pid)

            for i = 1, #list do
                local entry = list[i]
                if entry and entry.abil == ABIL_ID then
                    local need = entry.need or {}
                    local slOK = mySL >= (need.sl_min or 0)
                    local plOK = myPL >= (need.pl_min or 0)
                    local rlOK = (not need.role) or (need.role == myRole)
                    local fmOK = hasFamily(pid, need.family)

                    if slOK and plOK and rlOK and fmOK then
                        return true
                    end
                end
            end
        end

        -- fallback: older table style
        local all = GB.GetSpellUnlocks and GB.GetSpellUnlocks() or nil
        if all then
            local mySL  = getSoulLevel(pid)
            local myPL  = getPowerLevel(pid)
            local myRole= getRole(pid)
            for _, list in pairs(all) do
                if type(list) == "table" then
                    for i = 1, #list do
                        local entry = list[i]
                        if entry and entry.abil == ABIL_ID then
                            local need = entry.need or {}
                            local slOK = mySL >= (need.sl_min or 0)
                            local plOK = myPL >= (need.pl_min or 0)
                            local rlOK = (not need.role) or (need.role == myRole)
                            local fmOK = hasFamily(pid, need.family)
                            if slOK and plOK and rlOK and fmOK then
                                return true
                            end
                        end
                    end
                end
            end
        end

        return false
    end

    --------------------------------------------------
    -- writer: pipes through StatSystem so it STACKS
    --------------------------------------------------
    local function applyAS(pid, u)
        if _G.StatSystem and StatSystem.ApplySource then
            StatSystem.ApplySource(pid, SOURCE_KEY, {
                attackSpeedPct = BONUS_AS,  -- this is what inventory uses too
            })
            log("Applied AS to p"..pid.." = "..tostring(BONUS_AS))
        elseif _G.StatSystem and StatSystem.SetUnitStat then
            -- fallback: write directly to the unit
            StatSystem.SetUnitStat(u, StatSystem.STAT_ATTACK_SPEED, BONUS_AS)
            log("Fallback SetUnitStat for p"..pid)
        else
            -- super fallback: native wc3 (not ideal, but keeps it from being a noop)
            local base = BlzGetUnitAttackCooldown(u, 0)
            BlzSetUnitAttackCooldown(u, base * (1.0 - BONUS_AS), 0)
            log("Native fallback for p"..pid)
        end
    end

    local function clearAS(pid)
        if _G.StatSystem and StatSystem.RemoveSource then
            StatSystem.RemoveSource(pid, SOURCE_KEY)
            log("Cleared AS for p"..pid)
        end
    end

    --------------------------------------------------
    -- periodic watcher (so death/respawn/hero-swap is handled)
    --------------------------------------------------
    OnInit.final(function()
        local t = CreateTimer()
        TimerStart(t, 0.75, true, function()
            for pid = 0, bj_MAX_PLAYERS - 1 do
                local u = heroOf(pid)
                if u and IsPlayerSlotState(Player(pid), PLAYER_SLOT_STATE_PLAYING) then
                    if isSoulSpiritUnlocked(pid, u) then
                        applyAS(pid, u)
                    else
                        clearAS(pid)
                    end
                else
                    clearAS(pid)
                end
            end
        end)
        log("SoulSpirit watcher ready")
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
