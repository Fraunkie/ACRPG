if Debug and Debug.beginFile then Debug.beginFile("SoulEnergyLogic.lua") end
--==================================================
-- SoulEnergyLogic.lua  (XP-only, RuneScape curve)  [diag]
--==================================================

if not SoulEnergyLogic then SoulEnergyLogic = {} end
_G.SoulEnergyLogic = SoulEnergyLogic

do
    local MAX_LEVEL   = 120
    local START_LEVEL = 1

    local function emit(evt, payload)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then pcall(PB.Emit, evt, payload) end
    end

    -- THIS is the one that might be the issue: using PLAYER_DATA directly.
    -- we keep it, but we’ll show what it returns.
    local function PD(pid)
        if not PLAYER_DATA then PLAYER_DATA = {} end
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        local pd = PLAYER_DATA[pid]
        pd.soulXP    = pd.soulXP    or 0
        pd.soulLevel = pd.soulLevel or START_LEVEL
        return pd
    end

    --------------------------------------------------
    -- RuneScape table
    --------------------------------------------------
    local totalXpForLevel = {}
    local function buildRSTable()
        totalXpForLevel[1] = 0
        local acc = 0
        for L = 2, MAX_LEVEL do
            local i = L - 1
            local per = math.floor(i + 300.0 * (2.0 ^ (i / 7.0)))
            acc = acc + per
            totalXpForLevel[L] = math.floor(acc / 4.0)
        end
    end
    buildRSTable()

    function SoulEnergyLogic.LevelToTotalXp(level)
        if level <= 1 then return 0 end
        if level >= MAX_LEVEL then return totalXpForLevel[MAX_LEVEL] end
        return totalXpForLevel[level] or 0
    end

    function SoulEnergyLogic.XpToLevel(xp)
        if xp <= 0 then return 1 end
        local lo, hi = 1, MAX_LEVEL
        while lo < hi do
            local mid = math.floor((lo + hi + 1) / 2)
            if (totalXpForLevel[mid] or 0) <= xp then lo = mid else hi = mid - 1 end
        end
        if lo < 1 then lo = 1 end
        if lo > MAX_LEVEL then lo = MAX_LEVEL end
        return lo
    end

    function SoulEnergyLogic.LevelToNext(level)
        local cur = SoulEnergyLogic.LevelToTotalXp(level)
        local nxt = SoulEnergyLogic.LevelToTotalXp(level + 1)
        local need = nxt - cur
        return (need > 0) and need or 1
    end

    --------------------------------------------------
    -- core API
    --------------------------------------------------
    function SoulEnergyLogic.Get(pid)
        return PD(pid).soulXP or 0
    end

    function SoulEnergyLogic.GetXP(pid)
        return PD(pid).soulXP or 0
    end

    function SoulEnergyLogic.GetLevel(pid)
        return PD(pid).soulLevel or START_LEVEL
    end

 local function applyLevelRecalc(pid, pd)
    local old = pd.soulLevel or START_LEVEL
    local new = SoulEnergyLogic.XpToLevel(pd.soulXP or 0)
    pd.soulLevel = new

    if new > old then
        local gained = new - old

        -- try to get hero (can be nil early)
        local u = nil
        if _G.PlayerData and PlayerData.GetHero then
            u = PlayerData.GetHero(pid)
        end

        -- how much per level (for the hero stats)
        local perLevel = 3

        -- run once per level gained so big XP jumps still give stats
        for _ = 1, gained do
            -- Call HeroStatSystem's OnLevelUp function to handle per-level stat increases
            if u and _G.HeroStatSystem and HeroStatSystem.OnLevelUp then
                HeroStatSystem.OnLevelUp(pid, 1) -- You can pass `1` to indicate the level-up increment
            end
        end

        -- Sync updated base stats into PlayerData after the level-up
        if _G.PlayerData and PlayerData.SetStats then
            local pdStats = PlayerData.GetStats(pid)
            pdStats.power   = (pdStats.power or 0) + perLevel
            pdStats.defense = (pdStats.defense or 0) + math.floor((pdStats.basestr or 0) * 0.5)
            pdStats.speed   = (pdStats.speed or 0) + math.floor((pdStats.baseagi or 0) * 0.75)
        end

        -- fire level-up event like before
        emit("OnSoulLevelUp", { pid = pid, level = new, gained = gained })
    end
end



    function SoulEnergyLogic.Set(pid, xp)
        local pd = PD(pid)
        local newXp = math.max(0, tonumber(xp) or 0)
        pd.soulXP = newXp
        applyLevelRecalc(pid, pd)
        emit("OnSoulXPChanged", { pid = pid, xp = newXp })
        emit("OnSoulChanged",   { pid = pid, value = newXp })
        return newXp
    end

    -- THIS is what your chat command should be hitting.
    function SoulEnergyLogic.Add(pid, delta, reason, meta)
        local d = tonumber(delta) or 0
        if d <= 0 then
            -- show we got called but ignored
            DisplayTextToPlayer(Player(pid), 0, 0, "[SoulLogic] Add called but delta <= 0 (" .. tostring(d) .. ")")
            return PD(pid).soulXP or 0
        end

        local pd = PD(pid)
        local before = pd.soulXP or 0

        pd.soulXP = before + d
        applyLevelRecalc(pid, pd)

        emit("OnSoulXPChanged", { pid = pid, xp = pd.soulXP })
        emit("OnSoulChanged",   { pid = pid, value = pd.soulXP })
        emit("OnSoulPing",      { pid = pid, delta = d })

        -- DIAG: show actual write
        DisplayTextToPlayer(Player(pid), 0, 0,
            "[SoulLogic] pid=" .. tostring(pid) ..
            " before=" .. tostring(before) ..
            " + " .. tostring(d) ..
            " => " .. tostring(pd.soulXP))

        return pd.soulXP
    end

    -- Award XP based on unit type and HFILUnitConfig
function AwardXPFromHFILUnitConfig(kpid, dead)
    -- Ensure HFILUnitConfig is available
    if not rawget(_G, "HFILUnitConfig") then
        print("HFILUnitConfig is not available.")
        return
    end

    local unitTypeId = GetUnitTypeId(dead)  -- Get the unit type ID of the dead unit

    -- Fetch the XP reward from HFILUnitConfig using unitTypeId
    local unitConfig = HFILUnitConfig.GetByTypeId(unitTypeId)
    
    local baseXP = 0
    if unitConfig and unitConfig.baseSoul then
        baseXP = unitConfig.baseSoul  -- Fetch base XP from the unit config
    else
        -- Fallback to GameBalance if no entry in HFILUnitConfig
        baseXP = GameBalance.XP_PER_KILL_BASE or 0
    end

    -- If baseXP is greater than 0, apply XP to the player
    if baseXP > 0 and kpid and _G.SoulEnergy and SoulEnergy.AddXp then
        print("Adding XP to player:", kpid, "XP:", baseXP)  -- Debug log
        pcall(SoulEnergy.AddXp, kpid, baseXP)
    else
        print("No XP to add for player:", kpid)
    end
end


    function SoulEnergyLogic.Spend(pid, cost)
        return false
    end

    function SoulEnergyLogic.Ping(pid, amount)
        emit("OnSoulPing", { pid = pid, delta = amount or 0 })
    end

    --------------------------------------------------

    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SoulEnergyLogic")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
