if Debug and Debug.beginFile then Debug.beginFile("HeroStatSystem.lua") end
if not HeroStatSystem then HeroStatSystem = {} end
_G.HeroStatSystem = HeroStatSystem

do
    --------------------------------------------------
    -- Defaults
    --------------------------------------------------
    local DEFAULT_STATS = {
        strength                = 10,
        agility                 = 10,
        intelligence            = 10,
        armor                   = 0,
        damage                  = 20,
        energyDamage            = 0,
        -- store chance stats as 0–1 FRACTIONS
        energyResist            = 0.01,   -- 1% as fraction
        dodge                   = 0.02,   -- 2% as fraction
        parry                   = 0.01,   -- 1% as fraction
        block                   = 0.01,   -- 1% as fraction
        critChance              = 0.05,   -- 5% as fraction
        critMult                = 1.50,   -- 1.5x crit multiplier
        spellBonusPct           = 0.00,
        physicalBonusPct        = 0.00,
        strmulti                = 1.0,
        agimulti                = 1.0,
        intmulti                = 1.0,
        speed                   = 0.00,
        xpBonusPercent          = 0.00
    }

    -- per-player stat bags (does NOT require hero to exist yet)
    local HERO_STATS = {}  -- [pid] = { ... }

    --------------------------------------------------
    -- internal: make sure table exists and is sane
    --------------------------------------------------
    local function ensure(pid)
        local t = HERO_STATS[pid]
        if not t then
            t = {
                strength                = DEFAULT_STATS.strength,
                agility                 = DEFAULT_STATS.agility,
                intelligence            = DEFAULT_STATS.intelligence,
                armor                   = DEFAULT_STATS.armor,
                damage                  = DEFAULT_STATS.damage,
                energyDamage            = DEFAULT_STATS.energyDamage,
                energyResist            = DEFAULT_STATS.energyResist,
                dodge                   = DEFAULT_STATS.dodge,
                critChance              = DEFAULT_STATS.critChance,
                critMult                = DEFAULT_STATS.critMult,
                spellBonusPct           = DEFAULT_STATS.spellBonusPct,
                physicalBonusPct        = DEFAULT_STATS.physicalBonusPct,
                strmulti                = DEFAULT_STATS.strmulti,
                agimulti                = DEFAULT_STATS.agimulti,
                intmulti                = DEFAULT_STATS.intmulti,
                speed                   = DEFAULT_STATS.speed,
                xpBonusPercent          = DEFAULT_STATS.xpBonusPercent,
            }
            HERO_STATS[pid] = t
            return t
        end

        -- Ensure stats exist, if not, initialize to default
        if t.strength == nil then t.strength = DEFAULT_STATS.strength end
        if t.agility == nil then t.agility = DEFAULT_STATS.agility end
        if t.intelligence == nil then t.intelligence = DEFAULT_STATS.intelligence end
        if t.power == nil then t.power = 0 end
        if t.damage == nil then t.damage = 0 end
        if t.armor == nil then t.armor = 0 end
        if t.speed == nil then t.speed = 0 end
        if t.xpBonusPercent == nil then t.xpBonusPercent = 0 end
        if t.energyDamage == nil then t.energyDamage = 0 end
        if t.energyResist == nil then t.energyResist = DEFAULT_STATS.energyResist end
        if t.dodge == nil then t.dodge = DEFAULT_STATS.dodge end
        if t.parry == nil then t.parry = DEFAULT_STATS.parry end
        if t.block == nil then t.block = DEFAULT_STATS.block end
        if t.critChance == nil then t.critChance = DEFAULT_STATS.critChance end
        if t.critMult == nil then t.critMult = DEFAULT_STATS.critMult end

        return t
    end

    --------------------------------------------------
    -- public init: call from CharacterCreation / Load
    --------------------------------------------------
    function HeroStatSystem.Recalculate(pid)
        local st = ensure(pid)  -- Ensure the stats table exists for the player

        -- Apply multipliers to the base stats
        local finalStrength     = (st.strength     or 0) * (st.strmulti or 1.0)
        local finalAgility      = (st.agility      or 0) * (st.agimulti or 1.0)
        local finalIntelligence = (st.intelligence or 0) * (st.intmulti or 1.0)

        -- Basic derived values
        st.power        = finalStrength + finalAgility + finalIntelligence
        st.armor        = math.floor(finalStrength * 0.5)     -- Derived armor from strength
        st.speed        = math.floor(finalAgility  * 0.75)    -- Derived speed from agility
        st.damage       = math.floor(finalAgility  * 1.2)
        st.crit         = math.floor(finalAgility  * 0.2)     -- Rating-style crit used for UI

        -- Energy damage from INT
        st.energyDamage = math.floor(finalIntelligence * 0.5)

        -- Chance-based stats: store as 0–1 fractions
        -- You can tune these per-stat scalars, caps are in fractions too.
        st.energyResist = st.energyResist or DEFAULT_STATS.energyResist

        -- 0.02% per AGI, clamped to 30%
        st.dodge        = math.min(finalAgility * 0.0002, 0.30)

        -- 0.015% per STR, clamped to 50%
        st.parry        = math.min(finalStrength * 0.00015, 0.50)

        -- 0.010% per STR, clamped to 30%
        st.block        = math.min(finalStrength * 0.00010, 0.30)

        -- 0.010% per AGI, clamped to 80% crit chance
        st.critChance   = math.min(finalAgility * 0.0001, 0.80)

        -- Multiplier, not percent
        st.critMult     = st.critMult or DEFAULT_STATS.critMult

        -- Directly push stats to PlayerData (no need for PlayerData.RefreshPower)
        local pd = PlayerData.Get(pid)
        pd.powerLevel          = st.power
        pd.stats.power         = st.power
        pd.stats.armor         = st.armor
        pd.stats.damage        = st.damage
        pd.stats.energyDamage  = st.energyDamage
        pd.stats.speed         = st.speed
        pd.stats.crit          = st.crit
        pd.stats.basestr       = finalStrength
        pd.stats.baseagi       = finalAgility
        pd.stats.baseint       = finalIntelligence
        pd.stats.strmulti      = st.strmulti
        pd.stats.agimulti      = st.agimulti
        pd.stats.intmulti      = st.intmulti

        -- Sync combat stats (from HeroStatSystem)
        pd.combat.energyDamage = st.energyDamage
        pd.combat.energyResist = st.energyResist
        pd.combat.damage       = st.damage
        pd.combat.armor        = st.armor
        pd.combat.dodge        = st.dodge
        pd.combat.parry        = st.parry
        pd.combat.block        = st.block
        pd.combat.critChance   = st.critChance
        pd.combat.critMult     = st.critMult
        pd.xpBonusPercent      = st.xpBonusPercent

        -- Apply derived stats to the hero (unit stats)
        local hero = PlayerData.GetHero(pid)
        if hero then
            SetHeroStr(hero, finalStrength, true)
            SetHeroAgi(hero, finalAgility, true)
            SetHeroInt(hero, finalIntelligence, true)
        end
        return st
    end

    --------------------------------------------------
    -- getters / setters
    --------------------------------------------------
    function HeroStatSystem.Get(pid, key)
        local st = ensure(pid)
        return st[key] or 0
    end

    function HeroStatSystem.Set(pid, key, value)
        local st = ensure(pid)
        st[key] = value or 0

        -- push to PlayerData mirror too
        if _G.PlayerData and PlayerData.Get then
            local pd = PlayerData.Get(pid)
            if pd then
                pd.stats = pd.stats or {}
                if key == "strength" then
                    pd.stats.basestr = value or 0
                elseif key == "agility" then
                    pd.stats.baseagi = value or 0
                elseif key == "power" then
                    pd.stats.power = value or 0
                elseif key == "armor" then
                    pd.combat.armor = value or 0
                elseif key == "damage" then
                    pd.combat.damage = value or 0
                elseif key == "intelligence" then
                    pd.stats.baseint = value or 0
                -- Sync other stats
                elseif key == "speed" then
                    pd.stats.speed = value or 0
                elseif key == "critChance" then
                    pd.stats.critChance = value or 0
                -- Sync combat stats
                elseif key == "energyDamage" then
                    pd.combat.energyDamage = value or 0
                elseif key == "energyResist" then
                    pd.combat.energyResist = value or 0
                elseif key == "dodge" then
                    pd.combat.dodge = value or 0
                elseif key == "parry" then
                    pd.combat.parry = value or 0
                elseif key == "block" then
                    pd.combat.block = value or 0
                elseif key == "critMult" then
                    pd.combat.critMult = value or 0
                elseif key == "spellBonusPct" then
                    pd.combat.spellBonusPct = value or 0
                elseif key == "physicalBonusPct" then
                    pd.combat.physicalBonusPct = value or 0
                elseif key == "xpBonusPercent" then
                    pd.combat.xpBonusPercent = value or 0
                end
            end
        end

        return st[key]
    end

    function HeroStatSystem.Add(pid, key, value)
        local st = ensure(pid)
        st[key] = (st[key] or 0) + (value or 0)

        -- push to PlayerData mirror too
        if _G.PlayerData and PlayerData.Get then
            local pd = PlayerData.Get(pid)
            if pd then
                pd.stats = pd.stats or {}
                if key == "strength" then
                    pd.stats.basestr = st[key]
                elseif key == "agility" then
                    pd.stats.baseagi = st[key]
                elseif key == "intelligence" then
                    pd.stats.baseint = st[key]
                elseif key == "armor" then
                    pd.combat.armor = st[key] or 0
                elseif key == "power" then
                    pd.stats.power = st[key] or 0
                -- Sync other stats
                elseif key == "speed" then
                    pd.stats.speed = st[key]
                elseif key == "critChance" then
                    pd.stats.critChance = st[key]
                -- Sync combat stats
                elseif key == "energyDamage" then
                    pd.combat.energyDamage = st[key]
                elseif key == "damage" then
                    pd.combat.damage = st[key]
                elseif key == "energyResist" then
                    pd.combat.energyResist = st[key]
                elseif key == "dodge" then
                    pd.combat.dodge = st[key]
                elseif key == "parry" then
                    pd.combat.parry = st[key]
                elseif key == "block" then
                    pd.combat.block = st[key]
                elseif key == "critMult" then
                    pd.combat.critMult = st[key]
                elseif key == "spellBonusPct" then
                    pd.combat.spellBonusPct = st[key]
                elseif key == "physicalBonusPct" then
                    pd.combat.physicalBonusPct = st[key]
                elseif key == "xpBonusPercent" then
                    pd.xpBonusPercent = st[key]
                end
            end
        end

        return st[key]
    end

    --------------------------------------------------
    -- recalc derived stuff (not level-up logic itself)
    --------------------------------------------------
    function HeroStatSystem.InitializeStats(pid, hero)
        ensure(pid)
        HeroStatSystem.Recalculate(pid)
    end

    --------------------------------------------------
    -- hook from soul-level-up (optional)
    -- call HeroStatSystem.OnLevelUp(pid, gained) from SoulEnergyLogic
    --------------------------------------------------
    function HeroStatSystem.OnLevelUp(pid, gained)
        local add = gained or 1
        if add <= 0 then return end

        -- +1 STR / +1 AGI / +1 INT per level gained (easy test)
        HeroStatSystem.Add(pid, "strength",     add)
        HeroStatSystem.Add(pid, "agility",      add)
        HeroStatSystem.Add(pid, "intelligence", add)

        HeroStatSystem.Recalculate(pid)
    end

    --------------------------------------------------
    -- debug helper
    --------------------------------------------------
    function HeroStatSystem.DebugPrint(pid)
        local st = ensure(pid)
        print("HERO STATS pid=" .. tostring(pid) ..
              " STR=" .. tostring(st.strength) ..
              " AGI=" .. tostring(st.agility) ..
              " INT=" .. tostring(st.intelligence) ..
              " PWR=" .. tostring(st.power) ..
              " DEF=" .. tostring(st.armor) ..
              " SPD=" .. tostring(st.speed) ..
              " CRT=" .. tostring(st.crit) ..
              " DMG=" .. tostring(st.damage) ..
              " ENERG_DMG=" .. tostring(st.energyDamage) ..
              " ENERG_RESIST=" .. tostring(st.energyResist) ..
              " DODGE=" .. tostring(st.dodge) ..
              " PARRY=" .. tostring(st.parry) ..
              " BLOCK=" .. tostring(st.block) ..
              " CRIT_CHANCE=" .. tostring(st.critChance) ..
              " CRIT_MULT=" .. tostring(st.critMult))
    end

    --------------------------------------------------
    -- init: make tables even before hero is created
    --------------------------------------------------
    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                ensure(pid)
            end
        end
    end)
end
if Debug and Debug.endFile then Debug.endFile() end
