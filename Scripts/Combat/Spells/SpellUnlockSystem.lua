if Debug and Debug.beginFile then Debug.beginFile("SpellUnlockSystem.lua") end
--==================================================
-- SpellUnlockSystem.lua (v2 — SoulEnergyLevel Edition)
--==================================================
-- Unlocks spells based on:
--   • Soul Energy Level  (SoulEnergy.GetLevel(pid))
--   • Power Level        (from PlayerData / HeroStatSystem)
--   • Role               (from PlayerData.role or default)
--   • Shard Family ownership (optional)
--
-- Requirements in GameBalance.GetSpellUnlocks():
--   {
--     abil = FourCC("A000"),
--     name = "Example Spell",
--     need = { sl_min = 10, pl_min = 150, role = "DPS", family = "Saiyan" }
--   }
--
-- Events triggered on unlock:
--   ProcBus.Emit("OnSpellUnlocked", { pid, abil, name, reason })
--==================================================

if not SpellUnlockSystem then SpellUnlockSystem = {} end
_G.SpellUnlockSystem = SpellUnlockSystem

do
    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end

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
        if pd and pd.role then return pd.role end
        if rawget(_G, "GameBalance") and GameBalance.GetRoleDefault then
            return GameBalance.GetRoleDefault()
        end
        return "DPS"
    end

    local function GetPowerLevel(pid)
        local pd = PLAYER_DATA and PLAYER_DATA[pid]
        if pd and type(pd.powerLevel) == "number" then return pd.powerLevel end
        return 0
    end

    local function GetSoulLevel(pid)
        if _G.SoulEnergy and SoulEnergy.GetLevel then
            local ok, v = pcall(SoulEnergy.GetLevel, pid)
            if ok and type(v) == "number" then return v end
        end
        return 1
    end

    local function HasFamily(pid, fam)
        if not fam or fam == "" then return true end
        local pd = PLAYER_DATA and PLAYER_DATA[pid]
        if not pd then return false end
        if pd.families and pd.families[fam] then return true end
        if pd.chargedFamilies and pd.chargedFamilies[fam] then return true end
        if pd.lastFamilyKey == fam then return true end
        return false
    end

    local function TryGiveAbility(u, abil)
        if not ValidUnit(u) or not abil then return false end
        if GetUnitAbilityLevel(u, abil) > 0 then return false end
        UnitAddAbility(u, abil)
        return true
    end

    --------------------------------------------------
    -- Evaluation
    --------------------------------------------------
    local function Evaluate(pid)
        local GB = rawget(_G, "GameBalance")
        if not GB or not GB.GetSpellUnlocks then return end
        local unlocks = GB.GetSpellUnlocks()
        if not unlocks then return end

        local u = Hero(pid)
        if not ValidUnit(u) then return end

        local role = GetRole(pid)
        local power = GetPowerLevel(pid)
        local soulLvl = GetSoulLevel(pid)

        for key, list in pairs(unlocks) do
            if type(list) == "table" then
                for i = 1, #list do
                    local entry = list[i]
                    local need = entry.need or {}

                    local reqSL = tonumber(need.sl_min or 0) or 0
                    local reqPL = tonumber(need.pl_min or 0) or 0
                    local reqRole = need.role
                    local reqFam = need.family

                    local roleOK = (not reqRole) or (reqRole == role)
                    local famOK = HasFamily(pid, reqFam)
                    local lvlOK = (soulLvl >= reqSL)
                    local powOK = (power >= reqPL)

                    if roleOK and famOK and lvlOK and powOK then
                        if TryGiveAbility(u, entry.abil) then
                            if rawget(_G, "ProcBus") and ProcBus.Emit then
                                ProcBus.Emit("OnSpellUnlocked", {
                                    pid = pid,
                                    abil = entry.abil,
                                    name = entry.name or "Unknown",
                                    reason = "auto",
                                })
                            end
                            print("[Unlock] " .. tostring(entry.name) ..
                                  " (p" .. pid .. ", SL " .. soulLvl ..
                                  ", PL " .. power .. ")")
                            SpellUnlockSystem.Refresh(pid) -- Refresh UI after unlocking
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
            for i = 0, bj_MAX_PLAYERS - 1 do Evaluate(i) end
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

        -- Auto-refresh on XP/level/power changes
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnSoulLevelUp", function(e)
                if e and e.pid then Evaluate(e.pid) end
            end)
            PB.On("OnHeroPowerChanged", function(e)
                if e and e.pid then Evaluate(e.pid) end
            end)
            PB.On("OnFamilyGained", function(e)
                if e and e.pid then Evaluate(e.pid) end
            end)
        end

        print("[SpellUnlockSystem] Ready (SoulEnergyLevel mode)")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SpellUnlockSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
