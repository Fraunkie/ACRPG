if Debug and Debug.beginFile then Debug.beginFile("CombatAI_Spells.lua") end
--==================================================
-- CombatAI_Spells.lua
-- Simple creep spell casting based on:
--  • HP thresholds (pct)
--  • periodic timers
--  • current threat leader target
-- Reads optional per unit config from HFIL_UnitConfig.abilities.
--==================================================

if not CombatAI_Spells then CombatAI_Spells = {} end
_G.CombatAI_Spells = CombatAI_Spells

do
    --------------------------------------------------
    -- Tunables
    --------------------------------------------------
    local TICK_SEC            = 0.25
    local MAX_CAST_RANGE      = 800.0
    local IN_COMBAT_GRACE_SEC = 2.0

    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- tracked[unit] = { lastSeen = os.clock, perSpell = { [orderId] = lastCastClock } }
    local tracked = {}

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
    end
    local function isHero(u) return IsUnitType(u, UNIT_TYPE_HERO) end
    local function isBag(u)
        return (type(GetUnitUserData) == "function") and (GetUnitUserData(u) == 99999)
    end
    local function dist2(a, b)
        local dx, dy = GetUnitX(a) - GetUnitX(b), GetUnitY(a) - GetUnitY(b)
        return dx*dx + dy*dy
    end
    local function hpPct(u)
        local cur = GetWidgetLife(u)
        local mx  = BlzGetUnitMaxHP(u) or 1
        if mx <= 0 then return 0 end
        return (cur / mx) * 100.0
    end
    local function nowClock()
        if os and os.clock then return os.clock() end
        return 0
    end
    local function dprint(s)
        if _G.DevMode and type(DevMode.IsEnabled)=="function" and DevMode.IsEnabled() then
            print("[AI] " .. tostring(s))
        end
    end

    -- fetch per unit ability rules from HFIL_UnitConfig
    local function getAbilitiesFor(u)
        if not _G.HFILUnitConfig or not HFILUnitConfig.GetByTypeId then return nil end
        local row = HFILUnitConfig.GetByTypeId(GetUnitTypeId(u))
        if not row then return nil end
        return row.abilities
    end

    local function topThreatHeroFor(target)
        if not _G.ThreatSystem or not ThreatSystem.GetLeader then return nil end
        local leaderId, _ = ThreatSystem.GetLeader(target)
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
        local last = per and per[ord] or nil
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
    -- Core evaluation
    --------------------------------------------------
    local function evalOne(u)
        if not validUnit(u) or isHero(u) or isBag(u) then return end

        local abilities = getAbilitiesFor(u)
        if not abilities or #abilities == 0 then return end

        local hp = hpPct(u)
        local leader = topThreatHeroFor(u)
        local haveLeader = leader and validUnit(leader) and not isBag(leader)
        local inRange = haveLeader and (dist2(u, leader) <= (MAX_CAST_RANGE * MAX_CAST_RANGE)) or false
        local now = nowClock()

        for i = 1, #abilities do
            local a = abilities[i]
            local ord = tonumber(a.orderId or 0) or 0
            if ord ~= 0 and canCast(u, ord, a.cooldown or 0) then
                local passHp = true
                if a.castWhenHpBelow ~= nil then
                    passHp = hp <= (a.castWhenHpBelow or 0)
                end
                local passTimer = true
                if a.castEvery ~= nil then
                    local st = tracked[u]; st.perSpell = st.perSpell or {}
                    local last = st.perSpell[ord]
                    if last then
                        passTimer = (now - last) >= (a.castEvery or 0)
                    end
                end

                local needsLeader = (a.target == "leader")
                local targetOk = (not needsLeader) or (haveLeader and inRange)

                if passHp and passTimer and targetOk then
                    issueOrder(u, ord, a.target or "self", needsLeader and leader or nil)
                    markCast(u, ord)
                    dprint("cast " .. tostring(ord) .. " by " .. GetUnitName(u) .. (needsLeader and (" onto " .. GetUnitName(leader)) or ""))
                end
            end
        end
    end

    --------------------------------------------------
    -- Tick and cleanup
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
