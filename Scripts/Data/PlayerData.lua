if Debug and Debug.beginFile then Debug.beginFile("PlayerData.lua") end
--==================================================
-- PlayerData.lua
-- Single source of truth for per-player runtime state.
--  - Long-lived, cross-system data lives here
--  - System-specific logic stays in its own module
--  - Mirrors read-only combat stats from HeroStatSystem
--==================================================

if not PlayerData then PlayerData = {} end
_G.PlayerData = PlayerData
PLAYER_DATA = PLAYER_DATA or {}
PlayerHero  = PlayerHero or {}

do
    --------------------------------------------------
    -- Defaults
    --------------------------------------------------
    local function defaultTable()
        return {
            -- identity / session
            hero = nil,
            zone = "YEMMA",
            role = "NONE",
            hasStarted = false,

            -- power/progression mirrors
            powerLevel = 0,
            soulEnergy = 0,
            soulLevel  = 1,
            soulXP     = 0,
            soulNextXP = 200,
            spiritDrive = 0,

            -- read-only combat stats mirror
            stats = { power = 0, defense = 0, speed = 0, crit = 0 },

            -- combat detail stats
            combat = {
                armor         = 0,
                energyResist  = 0,
                dodge         = 0,
                parry         = 0,
                block         = 0,
                critChance    = 0,
                critMult      = 1.5,
                -- NEW: % spell power bonus (e.g., from items, talents)
                -- expressed as 0.10 = +10% spell damage
                spellBonusPct = 0.0,
            },

            -- loot / shards
            fragments   = 0,
            ownedShards = {},

            -- UX flags
            lootChatEnabled   = true,
            yemmaPromptShown  = false,
            yemmaPromptMinimized = false,

            -- intro/meta
            introChoice    = nil,
            introCompleted = false,
            introStyle     = nil,

            -- tasks / teleports
            hfilTask   = { active=false, id=nil, name="", desc="", goalType="", need=0, have=0, rarity="Common" },
            activeTask = nil,
            teleports  = {},

            -- optional misc bonuses
            xpBonusPercent       = 0,
            statChanceBonusPermil= 0,
            dropLuckBonusPermil  = 0,
        }
    end

    --------------------------------------------------
    -- Accessors
    --------------------------------------------------
    function PlayerData.Get(pid)
        local t = PLAYER_DATA[pid]
        if t == nil then
            t = defaultTable()
            PLAYER_DATA[pid] = t
        end
        return t
    end

    function PlayerData.GetField(pid, key, defaultValue)
        local t = PlayerData.Get(pid)
        local v = t[key]
        if v == nil then return defaultValue end
        return v
    end

    --------------------------------------------------
    -- Hero binding
    --------------------------------------------------
    function PlayerData.SetHero(pid, unit)
        local pd = PlayerData.Get(pid)
        pd.hero = unit
        PlayerHero[pid] = unit
        return unit
    end

    function PlayerData.GetHero(pid)
        local pd = PlayerData.Get(pid)
        return pd.hero
    end

    --------------------------------------------------
    -- Power mirror refresh
    --------------------------------------------------
    function PlayerData.RefreshPower(pid)
        local pd = PlayerData.Get(pid)
        local str = (rawget(_G, "PlayerMStr") and PlayerMStr[pid]) or 0
        local agi = (rawget(_G, "PlayerMAgi") and PlayerMAgi[pid]) or 0
        local int = (rawget(_G, "PlayerMInt") and PlayerMInt[pid]) or 0
        pd.powerLevel = math.max(0, math.floor((str + agi + int) / 3))
        return pd.powerLevel
    end

    --------------------------------------------------
    -- Souls / shards
    --------------------------------------------------
    function PlayerData.AddSoul(pid, amount)
        local pd = PlayerData.Get(pid)
        pd.soulEnergy = math.max(0, (pd.soulEnergy or 0) + (amount or 0))
        return pd.soulEnergy
    end

    function PlayerData.AddFragments(pid, amount)
        local pd = PlayerData.Get(pid)
        pd.fragments = math.max(0, (pd.fragments or 0) + (amount or 0))
        return pd.fragments
    end

    --------------------------------------------------
    -- Zone helpers
    --------------------------------------------------
    function PlayerData.SetZone(pid, zone)
        local pd = PlayerData.Get(pid)
        pd.zone = zone or pd.zone
        return pd.zone
    end

    function PlayerData.GetZone(pid)
        local pd = PlayerData.Get(pid)
        return pd.zone
    end

    --------------------------------------------------
    -- Basic stats mirror (from HeroStatSystem)
    --------------------------------------------------
    function PlayerData.SetStats(pid, tbl)
        local pd = PlayerData.Get(pid)
        local s = pd.stats or {}
        s.power   = (tbl and tbl.power)   or s.power   or 0
        s.defense = (tbl and tbl.defense) or s.defense or 0
        s.speed   = (tbl and tbl.speed)   or s.speed   or 0
        s.crit    = (tbl and tbl.crit)    or s.crit    or 0
        pd.stats = s
        return s
    end

    function PlayerData.GetStats(pid)
        local pd = PlayerData.Get(pid)
        local s = pd.stats
        if not s then
            s = { power = 0, defense = 0, speed = 0, crit = 0 }
            pd.stats = s
        end
        return s
    end

    --------------------------------------------------
    -- Combat stats (includes spellBonusPct)
    --------------------------------------------------
    function PlayerData.SetCombat(pid, tbl)
        local pd = PlayerData.Get(pid)
        local c = pd.combat or {}
        c.armor         = (tbl and tbl.armor)        or c.armor        or 0
        c.energyResist  = (tbl and tbl.energyResist) or c.energyResist or 0
        c.dodge         = (tbl and tbl.dodge)        or c.dodge        or 0
        c.parry         = (tbl and tbl.parry)        or c.parry        or 0
        c.block         = (tbl and tbl.block)        or c.block        or 0
        c.critChance    = (tbl and tbl.critChance)   or c.critChance   or 0
        c.critMult      = (tbl and tbl.critMult)     or c.critMult     or 1.5
        c.spellBonusPct = (tbl and tbl.spellBonusPct) or c.spellBonusPct or 0.0
        pd.combat = c
        return c
    end

    function PlayerData.GetCombat(pid)
        local pd = PlayerData.Get(pid)
        if not pd.combat then
            pd.combat = {
                armor         = 0,
                energyResist  = 0,
                dodge         = 0,
                parry         = 0,
                block         = 0,
                critChance    = 0,
                critMult      = 1.5,
                spellBonusPct = 0.0,
            }
        end
        return pd.combat
    end

    --------------------------------------------------
    -- Combat getters (for Damage/Spell systems)
    --------------------------------------------------
    function PlayerData.GetArmor(pid)        return PlayerData.GetCombat(pid).armor end
    function PlayerData.GetEnergyResist(pid) return PlayerData.GetCombat(pid).energyResist end
    function PlayerData.GetDodge(pid)        return PlayerData.GetCombat(pid).dodge end
    function PlayerData.GetParry(pid)        return PlayerData.GetCombat(pid).parry end
    function PlayerData.GetBlock(pid)        return PlayerData.GetCombat(pid).block end
    function PlayerData.GetCritChance(pid)   return PlayerData.GetCombat(pid).critChance end
    function PlayerData.GetCritMult(pid)     return PlayerData.GetCombat(pid).critMult end

    -- NEW: spell power % helpers
    function PlayerData.GetSpellBonusPct(pid)
        return PlayerData.GetCombat(pid).spellBonusPct or 0.0
    end
    function PlayerData.SetSpellBonusPct(pid, pct)
        local c = PlayerData.GetCombat(pid)
        c.spellBonusPct = tonumber(pct) or 0.0
        return c.spellBonusPct
    end
    function PlayerData.AddSpellBonusPct(pid, delta)
        local c = PlayerData.GetCombat(pid)
        c.spellBonusPct = (c.spellBonusPct or 0.0) + (tonumber(delta) or 0.0)
        return c.spellBonusPct
    end

    --------------------------------------------------
    -- Init / events
    --------------------------------------------------
    OnInit.final(function()
        -- ensure slots for human players
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                PLAYER_DATA[pid] = PLAYER_DATA[pid] or defaultTable()
            end
        end

        -- Mirror stat updates
        local function _PD_OnHeroStatsChanged(e)
            if not e or not e.unit then return end
            local p = GetPlayerId(GetOwningPlayer(e.unit))
            if p == nil then return end
            if _G.HeroStatSystem and HeroStatSystem.GetAll then
                local all = HeroStatSystem.GetAll(e.unit)
                PlayerData.SetStats(p, {
                    power   = (all and all.power)   or 0,
                    defense = (all and all.defense) or 0,
                    speed   = (all and all.speed)   or 0,
                    crit    = (all and all.crit)    or 0,
                })
            end
        end

        -- Optional: mirror combat stats from StatSystem (now includes spellBonusPct if provided)
        local function _PD_OnCombatStatsChanged(e)
            if not e or not e.unit then return end
            local p = GetPlayerId(GetOwningPlayer(e.unit))
            if p == nil then return end
            if _G.StatSystem and StatSystem.GetCombat then
                local all = StatSystem.GetCombat(e.unit)
                PlayerData.SetCombat(p, all)
            end
        end

        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("HeroStatsChanged", _PD_OnHeroStatsChanged)
            PB.On("CombatStatsChanged", _PD_OnCombatStatsChanged)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("PlayerData")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
