if Debug and Debug.beginFile then Debug.beginFile("CombatAI_Spells.lua") end
--==================================================
-- CombatAI_Spells.lua
-- Simple creep spell casting logic.
-- • HP thresholds, periodic timers, and threat leader targeting
-- • Reads ability configs from HFIL_UnitConfig.abilities
--==================================================

if not CombatAI_Spells then CombatAI_Spells = {} end
_G.CombatAI_Spells = CombatAI_Spells

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local TICK_SEC            = 0.25
    local MAX_CAST_RANGE      = 800.0
    local IN_COMBAT_GRACE_SEC = 2.0

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local tracked = {}  -- [unit] = { lastSeen=os.clock, perSpell={[orderId]=lastCastTime} }

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local CU = _G.CoreUtils or {}

    local function validUnit(u)
        return CU.ValidUnit and CU.ValidUnit(u) or (u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405)
    end
    local function isHero(u) return IsUnitType(u, UNIT_TYPE_HERO) end
    local function isBag(u) return CU.IsBag and CU.IsBag(u) end
    local function dist2(a, b)
        local dx, dy = GetUnitX(a) - GetUnitX(b), GetUnitY(a) - GetUnitY(b)
        return dx * dx + dy * dy
    end
    local function hpPct(u)
        local cur, mx = GetWidgetLife(u), BlzGetUnitMaxHP(u) or 1
        if mx <= 0 then return 0 end
        return (cur / mx) * 100
    end
    local function nowClock() return (os and os.clock) and os.clock() or 0 end

    local function dprint(s)
        local DM = rawget(_G, "DevMode")
        if DM and DM.IsOn and DM.IsOn(0) then print("[AI] " .. tostring(s)) end
    end

    local function getAbilitiesFor(u)
        if not _G.HFILUnitConfig or not HFILUnitConfig.GetByTypeId then return nil end
        local row = HFILUnitConfig.GetByTypeId(GetUnitTypeId(u))
        return row and row.abilities or nil
    end

    local function topThreatHeroFor(target)
        if not _G.ThreatSystem or not ThreatSystem.GetLeader then return nil end
        local leaderId = ThreatSystem.GetLeader(target)
        if not leaderId then return nil end
        if _G.PlayerData and PlayerData.Get then
            for pid = 0, bj_MAX_PLAYERS - 1 do
                local pd = PlayerData.Get(pid)
                if pd and pd.hero and GetHandleId(pd.hero) == leaderId then
                    return pd.hero
                end
            end
        end
        return nil
    end

    local function canCast(u, ord, cd)
        local st = tracked[u]
        if not st then return true end
        local per = st.perSpell
        local last = per and per[ord]
        if not last then return true end
        if cd and cd > 0 then
            return (nowClock() - last) >= cd
        end
        return true
    end

    local function markCast(u, ord)
        local st = tracked[u]; if not st then return end
        st.perSpell = st.perSpell or {}
        st.perSpell[ord] = nowClock()
    end

    local function issueOrder(u, ord, tgtMode, tgtUnit)
        if tgtMode == "self" or not tgtUnit then
            IssueImmediateOrderById(u, ord)
        else
            IssueTargetOrderById(u, ord, tgtUnit)
        end
    end

    --------------------------------------------------
    -- Evaluation per creep
    --------------------------------------------------
    local function evalOne(u)
        if not validUnit(u) or isHero(u) or isBag(u) then return end
        local abilities = getAbilitiesFor(u)
        if not abilities or #abilities == 0 then return end

        local hp = hpPct(u)
        local leader = topThreatHeroFor(u)
        local haveLeader = leader and validUnit(leader) and not isBag(leader)
        local inRange = haveLeader and (dist2(u, leader) <= (MAX_CAST_RANGE * MAX_CAST_RANGE))
        local now = nowClock()

        for i = 1, #abilities do
            local a = abilities[i]
            local ord = tonumber(a.orderId or 0) or 0
            if ord ~= 0 and canCast(u, ord, a.cooldown or 0) then
                local passHp = (a.castWhenHpBelow == nil) or (hp <= (a.castWhenHpBelow or 0))
                local passTimer = true
                if a.castEvery then
                    local st = tracked[u]; st.perSpell = st.perSpell or {}
                    local last = st.perSpell[ord]
                    if last then passTimer = (now - last) >= a.castEvery end
                end

                local needsLeader = (a.target == "leader")
                local targetOk = (not needsLeader) or (haveLeader and inRange)
                if passHp and passTimer and targetOk then
                    issueOrder(u, ord, a.target or "self", needsLeader and leader or nil)
                    markCast(u, ord)
                    dprint("cast " .. tostring(ord) .. " by " .. GetUnitName(u))
                end
            end
        end
    end

    --------------------------------------------------
    -- Periodic tick
    --------------------------------------------------
    local function tick()
        local t = nowClock()
        for u, st in pairs(tracked) do
            if not validUnit(u) then
                tracked[u] = nil
            else
                if (t - (st.lastSeen or 0)) > IN_COMBAT_GRACE_SEC then
                    tracked[u] = nil
                else
                    evalOne(u)
                end
            end
        end
    end

    --------------------------------------------------
    -- Wiring to combat events
    --------------------------------------------------
    local function onDamage(e)
        if not e or not e.target then return end
        local u = e.target
        if not validUnit(u) or isHero(u) or isBag(u) then return end
        local st = tracked[u] or { lastSeen = nowClock(), perSpell = {} }
        st.lastSeen = nowClock()
        tracked[u] = st
    end

    local function onKill(e)
        if not e or not e.target then return end
        tracked[e.target] = nil
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnDealtDamage", onDamage)
            PB.On("OnKill", onKill)
        end
        local tm = CreateTimer()
        TimerStart(tm, TICK_SEC, true, tick)

        print("[CombatAI_Spells] ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CombatAI_Spells")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
