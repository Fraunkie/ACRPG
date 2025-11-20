if Debug and Debug.beginFile then Debug.beginFile("SpellUnlockSystem.lua") end
--==================================================
-- SpellUnlockSystem.lua (v3 — ByUnit + knownspells)
--==================================================
-- Unlocks spells based on:
--   • Soul Energy Level  (SoulEnergy.GetLevel(pid) or fallback)
--   • Power Level        (from PlayerData.powerLevel)
--   • Role               (from PlayerData.role or GameBalance default)
--   • Shard Family ownership (optional, same as old version)
--
-- Requirements in GameBalance.SPELL_UNLOCKS_BY_UNIT:
--   {
--     name = "Phantom Echo",
--     abil = "A0PE", -- string rawcode
--     type = "passive" | "active",
--     need = {
--       sl_min    = 5,
--       pl_min    = 0,
--       role      = "DPS",
--       family    = "Saiyan",
--       checkname = "phantomEcho", -- key inside PlayerData.knownspells.*
--     }
--   }
--==================================================

if not SpellUnlockSystem then SpellUnlockSystem = {} end
_G.SpellUnlockSystem = SpellUnlockSystem

do
    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function ValidUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function Hero(pid)
        if PlayerData and PLAYER_DATA[pid] and ValidUnit(PLAYER_DATA[pid].hero) then
            return PLAYER_DATA[pid].hero
        end
        if _G.PlayerHero and ValidUnit(PlayerHero[pid]) then
            return PlayerHero[pid]
        end
        return nil
    end

    local function GetRole(pid)
        local pd = PLAYER_DATA and PLAYER_DATA[pid]
        if pd and pd.role then
            return pd.role
        end
        if rawget(_G, "GameBalance") and GameBalance.GetRoleDefault then
            return GameBalance.GetRoleDefault()
        end
        return "DPS"
    end

    local function GetPowerLevel(pid)
        local pd = PLAYER_DATA and PLAYER_DATA[pid]
        if pd and type(pd.powerLevel) == "number" then
            return pd.powerLevel
        end
        return 0
    end

    local function GetSoulLevel(pid)
        if _G.SoulEnergy and SoulEnergy.GetLevel then
            local ok, v = pcall(SoulEnergy.GetLevel, pid)
            if ok and type(v) == "number" then
                return v
            end
        end
        -- Fallback to PlayerData mirror if needed
        if PlayerData and PlayerData.Get then
            local pd = PlayerData.Get(pid)
            if pd and type(pd.soulLevel) == "number" then
                return pd.soulLevel
            end
        end
        return 1
    end

    local function HasFamily(pid, fam)
        if not fam or fam == "" then
            return true
        end
        local pd = PLAYER_DATA and PLAYER_DATA[pid]
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

    local function isPassiveEntry(entry)
        if not entry then
            return false
        end
        if entry.type == "passive" then
            return true
        end
        if entry.flags and type(entry.flags) == "table" then
            for _, f in ipairs(entry.flags) do
                if f == "passive" then
                    return true
                end
            end
        end
        return false
    end

    --------------------------------------------------
    -- knownspells helpers (uses PlayerData.Get)
    --------------------------------------------------
    local function ensureKnownTables(pid)
        local pd
        if PlayerData and PlayerData.Get then
            pd = PlayerData.Get(pid)
        else
            pd = PLAYER_DATA and PLAYER_DATA[pid]
            if not pd then
                return nil
            end
        end

        if not pd.knownspells then
            pd.knownspells = {
                passives = {},
                actives  = {},
            }
        else
            pd.knownspells.passives = pd.knownspells.passives or {}
            pd.knownspells.actives  = pd.knownspells.actives  or {}
        end

        return pd.knownspells
    end

    local function getBucketForEntry(pid, entry)
        local known = ensureKnownTables(pid)
        if not known then
            return nil
        end

        if isPassiveEntry(entry) then
            return known.passives
        end
        return known.actives
    end

    local function markKnown(pid, entry)
        local need = entry.need or {}
        local checkname = need.checkname
        if not checkname or checkname == "" then
            return
        end

        local bucket = getBucketForEntry(pid, entry)
        if not bucket then
            return
        end

        if bucket[checkname] == true then
            return
        end

        bucket[checkname] = true
    end

    local function isKnown(pid, entry)
        local need = entry.need or {}
        local checkname = need.checkname
        if not checkname or checkname == "" then
            return false
        end

        local bucket = getBucketForEntry(pid, entry)
        if not bucket then
            return false
        end

        return bucket[checkname] == true
    end

    --------------------------------------------------
    -- Ability give helper
    --------------------------------------------------
    local function TryGiveAbility(u, abil)
        if not ValidUnit(u) or not abil then
            return false
        end
        if GetUnitAbilityLevel(u, abil) > 0 then
            return false
        end
        UnitAddAbility(u, abil)
        return true
    end

    --------------------------------------------------
    -- Evaluation (per player)
    --------------------------------------------------
    local function Evaluate(pid)
        local GB = rawget(_G, "GameBalance")
        if not GB then
            return
        end

        local perUnit = (GB.GetSpellUnlocksByUnit and GB.GetSpellUnlocksByUnit())
            or GB.SPELL_UNLOCKS_BY_UNIT
        if not perUnit then
            return
        end

        local hero = Hero(pid)
        if not ValidUnit(hero) then
            return
        end

        local unitTypeId = GetUnitTypeId(hero)
        local list = perUnit[unitTypeId]
        if not list then
            return
        end

        local role    = GetRole(pid)
        local power   = GetPowerLevel(pid)
        local soulLvl = GetSoulLevel(pid)

        for i = 1, #list do
            local entry = list[i]
            if entry then
                local need = entry.need or {}

                local reqSL   = tonumber(need.sl_min or 0) or 0
                local reqPL   = tonumber(need.pl_min or 0) or 0
                local reqRole = need.role
                local reqFam  = need.family

                local roleOK = (not reqRole) or (reqRole == role)
                local famOK  = HasFamily(pid, reqFam)
                local lvlOK  = (soulLvl >= reqSL)
                local powOK  = (power >= reqPL)

                if roleOK and famOK and lvlOK and powOK then
                    -- Convert abil string to FourCC if needed
                    local abilId = entry.abil
                    if type(abilId) == "string" then
                        abilId = FourCC(abilId)
                    end

                    local alreadyKnown = isKnown(pid, entry)
                    local gaveAbility  = false

                    if abilId and abilId ~= 0 then
                        gaveAbility = TryGiveAbility(hero, abilId)
                    end

                    if (not alreadyKnown) or gaveAbility then
                        markKnown(pid, entry)

                        if rawget(_G, "ProcBus") and ProcBus.Emit then
                            ProcBus.Emit("OnSpellUnlocked", {
                                pid   = pid,
                                abil  = abilId,
                                name  = entry.name or "Unknown",
                                kind  = entry.type or "spell",
                                reason = "auto",
                            })
                        end

                        if Debug and Debug.log then
                            Debug.log(
                                "[SpellUnlock] " ..
                                tostring(entry.name) ..
                                " (p" .. tostring(pid) ..
                                ", SL " .. tostring(soulLvl) ..
                                ", PL " .. tostring(power) .. ")"
                            )
                        end
                    end
                end
            end
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function SpellUnlockSystem.Refresh(pid)
        if pid == nil then
            for i = 0, bj_MAX_PLAYERS - 1 do
                Evaluate(i)
            end
        else
            Evaluate(pid)
        end
    end

    --------------------------------------------------
    -- Init + hooks
    --------------------------------------------------
    OnInit.final(function()
        -- Initial pass
        TimerStart(CreateTimer(), 0.25, false, function()
            for pid = 0, bj_MAX_PLAYERS - 1 do
                Evaluate(pid)
            end
        end)

        -- Auto-refresh on XP/level/power/family changes
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnSoulLevelUp", function(e)
                if e and e.pid ~= nil then
                    Evaluate(e.pid)
                end
            end)
            PB.On("OnHeroPowerChanged", function(e)
                if e and e.pid ~= nil then
                    Evaluate(e.pid)
                end
            end)
            PB.On("OnFamilyGained", function(e)
                if e and e.pid ~= nil then
                    Evaluate(e.pid)
                end
            end)
        end

        if Debug and Debug.log then
            Debug.log("[SpellUnlockSystem] Ready (ByUnit + knownspells)")
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SpellUnlockSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
