if Debug and Debug.beginFile then Debug.beginFile("SoulEnergyLogic.lua") end
--==================================================
-- SoulEnergyLogic.lua  (XP-only, RuneScape curve)
-- • soulXp   = cumulative XP (never decreases)
-- • soulLvl  = derived level from soulXp
--
-- Public API (kept for adapter compatibility; XP-only semantics):
--   Get(pid)                 -> XP total
--   Set(pid, xp)            -> set XP (clamped >=0), recalculates level
--   Add(pid, delta, reason, meta)
--       * delta <= 0 is ignored (XP never drops)
--   Spend(pid, cost)        -> always false (no currency to spend)
--   Ping(pid, amount)       -> UI ping event only (no state change)
--   GetXP(pid), GetLevel(pid)
--   LevelProgress(pid)      -> into, need, totalAtLevel, totalAtNext
--   XpToLevel(xp), LevelToTotalXp(level), LevelToNext(level)
--
-- Events (if ProcBus present):
--   OnSoulXPChanged { pid, xp }
--   OnSoulLevelUp   { pid, level, gained }
--   OnSoulPing      { pid, delta }
--   OnSoulChanged   { pid, value }  -- legacy mirror of XP for old UIs
--
-- Reward lookup retained:
--   GetReward(fourId)
--==================================================

if not SoulEnergyLogic then SoulEnergyLogic = {} end
_G.SoulEnergyLogic = SoulEnergyLogic

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local MAX_LEVEL   = 120
    local START_LEVEL = 1

    --------------------------------------------------
    -- Utils / Events
    --------------------------------------------------
    local function emit(evt, payload)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then pcall(PB.Emit, evt, payload) end
    end

    local function PD(pid)
        if not PLAYER_DATA then PLAYER_DATA = {} end
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        local pd = PLAYER_DATA[pid]
        pd.soulXp  = pd.soulXp  or 0
        pd.soulLvl = pd.soulLvl or START_LEVEL
        return pd
    end

    --------------------------------------------------
    -- RuneScape-style curve (precomputed)
    -- totalXpForLevel[L] = floor(sum_{i=1}^{L-1} floor(i + 300*2^(i/7)) / 4)
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
    -- Reward lookup (unchanged)
    --------------------------------------------------
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
            if row and type(row.baseSoul) == "number" then return math.max(0, row.baseSoul) end
        end
        if _G.HFIL_UnitConfig_Dev and HFIL_UnitConfig_Dev.GetByTypeId then
            local row = HFIL_UnitConfig_Dev.GetByTypeId(four)
            if row and type(row.baseSoul) == "number" then return math.max(0, row.baseSoul) end
        end
        return 0
    end

    function SoulEnergyLogic.GetReward(four)
        if type(four) ~= "number" then return 0 end
        local v = fromHFIL(four); if v > 0 then return v end
        v = fromBalance(four);    if v > 0 then return v end
        return 0
    end

    --------------------------------------------------
    -- Core API (XP-only)
    --------------------------------------------------
    function SoulEnergyLogic.Get(pid)           -- returns XP (legacy name kept)
        return PD(pid).soulXp or 0
    end

    function SoulEnergyLogic.GetXP(pid)
        return PD(pid).soulXp or 0
    end

    function SoulEnergyLogic.GetLevel(pid)
        return PD(pid).soulLvl or START_LEVEL
    end

    function SoulEnergyLogic.LevelProgress(pid)
        local pd = PD(pid)
        local lvl = pd.soulLvl
        local curTotal  = SoulEnergyLogic.LevelToTotalXp(lvl)
        local nextTotal = SoulEnergyLogic.LevelToTotalXp(lvl + 1)
        local into = (pd.soulXp or 0) - curTotal
        local need = nextTotal - curTotal
        if need < 1 then need = 1 end
        if into < 0 then into = 0 end
        return into, need, curTotal, nextTotal
    end

    local function applyLevelRecalc(pid, pd)
        local old = pd.soulLvl or START_LEVEL
        local new = SoulEnergyLogic.XpToLevel(pd.soulXp or 0)
        pd.soulLvl = new
        if new > old then
            emit("OnSoulLevelUp",  { pid = pid, level = new, gained = (new - old) })
        end
    end

    function SoulEnergyLogic.Set(pid, xp)
        local pd = PD(pid)
        local newXp = math.max(0, tonumber(xp) or 0)
        pd.soulXp = newXp
        applyLevelRecalc(pid, pd)
        emit("OnSoulXPChanged", { pid = pid, xp = newXp })
        -- Legacy mirror for UIs listening to OnSoulChanged
        emit("OnSoulChanged",   { pid = pid, value = newXp })
        return newXp
    end

    -- delta <= 0 is ignored (XP never decreases)
    function SoulEnergyLogic.Add(pid, delta, reason, meta)
        local d = tonumber(delta) or 0
        if d <= 0 then return PD(pid).soulXp or 0 end
        local pd = PD(pid)
        pd.soulXp = (pd.soulXp or 0) + d
        applyLevelRecalc(pid, pd)
        emit("OnSoulXPChanged", { pid = pid, xp = pd.soulXp })
        emit("OnSoulChanged",   { pid = pid, value = pd.soulXp }) -- legacy
        emit("OnSoulPing",      { pid = pid, delta = d })
        return pd.soulXp
    end

    -- XP-only system: cannot spend
    function SoulEnergyLogic.Spend(pid, cost)
        return false
    end

    function SoulEnergyLogic.Ping(pid, amount)
        emit("OnSoulPing", { pid = pid, delta = amount or 0 })
    end

    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SoulEnergyLogic")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
