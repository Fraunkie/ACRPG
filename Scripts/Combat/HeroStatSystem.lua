if not HeroStatSystem then HeroStatSystem = {} end
_G.HeroStatSystem = HeroStatSystem

do
    --------------------------------------------------
    -- Defaults
    --------------------------------------------------
    local DEFAULT_STATS = {
        strength     = 10,
        agility      = 10,
        intelligence = 10,
        power        = 0,
        defense      = 0,
        speed        = 0,
        crit         = 0,
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
                strength     = DEFAULT_STATS.strength,
                agility      = DEFAULT_STATS.agility,
                intelligence = DEFAULT_STATS.intelligence,
                power        = DEFAULT_STATS.power,
                defense      = DEFAULT_STATS.defense,
                speed        = DEFAULT_STATS.speed,
                crit         = DEFAULT_STATS.crit,
            }
            HERO_STATS[pid] = t
            return t
        end

        -- heal missing / bad fields
        if t.strength     == nil or t.strength     ~= t.strength     then t.strength     = DEFAULT_STATS.strength end
        if t.agility      == nil or t.agility      ~= t.agility      then t.agility      = DEFAULT_STATS.agility end
        if t.intelligence == nil or t.intelligence ~= t.intelligence then t.intelligence = DEFAULT_STATS.intelligence end
        if t.power        == nil or t.power        ~= t.power        then t.power        = DEFAULT_STATS.power end
        if t.defense      == nil or t.defense      ~= t.defense      then t.defense      = DEFAULT_STATS.defense end
        if t.speed        == nil or t.speed        ~= t.speed        then t.speed        = DEFAULT_STATS.speed end
        if t.crit         == nil or t.crit         ~= t.crit         then t.crit         = DEFAULT_STATS.crit end

        return t
    end

    --------------------------------------------------
    -- public init: call from CharacterCreation / Load
    -- Hero can be nil, we only care about pid
    --------------------------------------------------
    function HeroStatSystem.Recalculate(pid)
    local st = ensure(pid)

    -- apply multipliers to the base stats
    local finalStrength = (st.strength or 0) * (st.strmulti or 1.0)
    local finalAgility  = (st.agility  or 0) * (st.agimulti  or 1.0)
    local finalIntelligence = (st.intelligence or 0) * (st.intmulti or 1.0)

    -- basic derived values
    st.power   = finalStrength + finalAgility + finalIntelligence
    st.defense = math.floor(finalStrength * 0.5)
    st.speed   = math.floor(finalAgility * 0.75)
    st.crit    = math.floor(finalAgility * 0.2)

    -- apply derived stats to the hero (unit stats)
    local hero = PlayerData.GetHero(pid)
    if hero then
        SetHeroStr(hero, finalStrength, true)
        SetHeroAgi(hero, finalAgility, true)
        SetHeroInt(hero, finalIntelligence, true)
    end

    -- also refresh PlayerData power if we have it
    if _G.PlayerData and PlayerData.RefreshPower then
        PlayerData.RefreshPower(pid)
    end

    -- Sync updated base stats into PlayerData
    if _G.PlayerData and PlayerData.SetStats then
        PlayerData.SetStats(pid, {
            power   = st.power,
            defense = st.defense,
            speed   = st.speed,
            crit    = st.crit,
            -- Sync the base stats to PlayerData (with multipliers factored in)
            basestr = finalStrength,
            baseagi = finalAgility,
            baseint = finalIntelligence,
        })
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
                elseif key == "intelligence" then
                    pd.stats.baseint = value or 0
                end
            end
        end

        return st[key]
    end

    function HeroStatSystem.Add(pid, key, value)
        local st = ensure(pid)
        st[key] = (st[key] or 0) + (value or 0)

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
              " DEF=" .. tostring(st.defense) ..
              " SPD=" .. tostring(st.speed) ..
              " CRT=" .. tostring(st.crit))
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
