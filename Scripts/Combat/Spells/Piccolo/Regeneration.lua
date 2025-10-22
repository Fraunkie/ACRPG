if Debug and Debug.beginFile then Debug.beginFile("Piccolo_Regeneration.lua") end
--==================================================
-- Piccolo_Regeneration.lua  (A02F)
-- One spell, two behaviors:
--  • Passive: constant regen tick (every 1.0s)
--  • Active: no-target Channel that bursts a big heal on finish/cancel
-- Notes:
--  - All math guarded (no NaNs).
--  - Uses ModifierSystem.Apply if available for a brief armor buff.
--  - Always prints a result line and plays FX, even at full HP.
--==================================================

do
    -----------------------------
    -- CONFIG
    -----------------------------
    local ABIL_ID              = FourCC('A02F')

    -- Passive regen
    local PASSIVE_TICK_SEC     = 1.00
    local PASSIVE_INT_SCALE    = 0.20
    local PASSIVE_MIN_HEAL     = 1.0

    -- Active burst (tap or hold)
    local CHANNEL_MAX_SEC      = 1.25
    local HEAL_MISSING_MIN     = 0.15
    local HEAL_MISSING_MAX     = 0.35
    local HEAL_INT_MIN         = 2.00
    local HEAL_INT_MAX         = 4.00

    -- Brief protection after burst (applied through ModifierSystem if present)
    local ARMOR_BONUS          = 4
    local ARMOR_DUR            = 3.00
    local ARMOR_KEY            = "RegenArmor"

    -- FX
    local FX_CHANNEL_LOOP      = "Abilities\\Spells\\NightElf\\Rejuvenation\\RejuvenationTarget.mdl"
    local FX_RELEASE_BLOOM     = "Abilities\\Spells\\Undead\\DeathPact\\DeathPactTarget.mdl"

    local DEBUG_LOG            = true

    -----------------------------
    -- HELPERS
    -----------------------------
    local function ownerPrint(u, msg)
        if not DEBUG_LOG then return end
        local p = GetOwningPlayer(u)
        if GetLocalPlayer() == p then
            DisplayTextToPlayer(p, 0, 0, "[Regen] " .. tostring(msg))
        end
    end

    local function unitAlive(u)
        return u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
    end

    local function pidOf(u)
        return GetPlayerId(GetOwningPlayer(u))
    end

    local function nz(x, fallback)
        if type(x) ~= "number" then return fallback or 0.0 end
        if x ~= x then return fallback or 0.0 end
        if x == math.huge or x == -math.huge then return fallback or 0.0 end
        return x
    end

    local function clamp01(x)
        x = nz(x, 0.0)
        if x < 0 then return 0 end
        if x > 1 then return 1 end
        return x
    end

    local function getInt(pid)
        local v = 0
        if rawget(_G, "PlayerMInt") and type(PlayerMInt[pid]) == "number" then
            v = PlayerMInt[pid] or 0
        elseif _G.StatSystem then
            if StatSystem.GetInt then
                local ok, n = pcall(StatSystem.GetInt, pid); if ok and type(n) == "number" then v = n end
            elseif StatSystem.GetStat then
                local ok, n = pcall(StatSystem.GetStat, pid, "INT"); if ok and type(n) == "number" then v = n end
            end
        end
        return nz(v, 0)
    end

    local function getSpellBonusPct(pid)
        if _G.StatSystem and StatSystem.GetSpellBonusPct then
            local ok, v = pcall(StatSystem.GetSpellBonusPct, pid)
            if ok and type(v) == "number" then return math.max(0.0, v) end
        end
        return 0.0
    end

    local function healUnit(u, amount)
        amount = nz(amount, 0.0)
        if not unitAlive(u) or amount <= 0 then return 0 end
        local life = nz(GetWidgetLife(u), 0.0)
        local maxL = nz(GetUnitState(u, UNIT_STATE_MAX_LIFE), 0.0)
        local gain = math.max(0.0, math.min(amount, maxL - life))
        if gain > 0.0 then
            SetWidgetLife(u, life + gain)
        end
        return gain
    end

    local function playFX(model, x, y, onUnit)
        if onUnit then
            local fx = AddSpecialEffectTarget(model, onUnit, "origin")
            TimerStart(CreateTimer(), 1.00, false, function()
                DestroyEffect(fx); DestroyTimer(GetExpiredTimer())
            end)
        else
            local fx = AddSpecialEffect(model, x, y)
            DestroyEffect(fx)
        end
    end

    -----------------------------
    -- PASSIVE: tracking + tick
    -----------------------------
    local tracked = {}           -- [handleId] = unit
    local passiveTimer = nil
    local passiveAcc = 0.0

    local function startPassiveTimerIfNeeded()
        if passiveTimer then return end
        passiveTimer = CreateTimer()
        TimerStart(passiveTimer, 0.25, true, function()
            passiveAcc = passiveAcc + 0.25
            if passiveAcc + 1e-6 >= PASSIVE_TICK_SEC then
                passiveAcc = passiveAcc - PASSIVE_TICK_SEC
                local any = false
                for hid, unit in pairs(tracked) do
                    if unitAlive(unit) then
                        any = true
                        local pid = pidOf(unit)
                        local INT = getInt(pid)
                        local bonusPct = getSpellBonusPct(pid)
                        local baseHeal = nz(INT * PASSIVE_INT_SCALE, 0.0)
                        local total = math.max(PASSIVE_MIN_HEAL, baseHeal * (1.0 + bonusPct))
                        local gained = healUnit(unit, total)
                        -- Always show a line so the player sees the tick, even at full HP
                        playFX(FX_CHANNEL_LOOP, 0, 0, unit)
                        ownerPrint(unit, "+" .. tostring(math.floor(gained + 0.5)) .. " HP (Passive)")
                    else
                        tracked[hid] = nil
                    end
                end
                if not any then
                    PauseTimer(passiveTimer)
                    DestroyTimer(passiveTimer)
                    passiveTimer, passiveAcc = nil, 0.0
                end
            end
        end)
    end

    local function track(u)
        if not unitAlive(u) then return end
        local h = GetHandleId(u)
        if not tracked[h] then
            tracked[h] = u
            startPassiveTimerIfNeeded()
        end
    end

    -----------------------------
    -- ACTIVE: channel handling
    -----------------------------
    local channel = {} -- [hid] = { u=unit, t0=timer }

    local function startChannel(u)
        if not unitAlive(u) then return end
        local h = GetHandleId(u)
        track(u)
        if channel[h] then return end
        local t0 = CreateTimer()
        -- long timer to read elapsed time safely
        TimerStart(t0, 3600.0, false, function() end)
        channel[h] = { u = u, t0 = t0 }
        playFX(FX_CHANNEL_LOOP, 0, 0, u)
    end

    local function finishChannel(u)
        if not unitAlive(u) then return end
        local h = GetHandleId(u)
        local st = channel[h]
        if not st then
            playFX(FX_RELEASE_BLOOM, GetUnitX(u), GetUnitY(u))
            ownerPrint(u, "+0 HP (Burst 0.00s)")
            return
        end

        local elapsed = 0.0
        if st.t0 then
            elapsed = nz(TimerGetElapsed(st.t0), 0.0)
            DestroyTimer(st.t0)
        end
        channel[h] = nil

        local f = clamp01(elapsed / CHANNEL_MAX_SEC)

        local pid = pidOf(u)
        local INT = getInt(pid)
        local maxL = nz(GetUnitState(u, UNIT_STATE_MAX_LIFE), 0.0)
        local curL = nz(GetWidgetLife(u), 0.0)
        local missing = math.max(0.0, maxL - curL)

        local missPct = HEAL_MISSING_MIN + (HEAL_MISSING_MAX - HEAL_MISSING_MIN) * f
        local intPart = HEAL_INT_MIN + (HEAL_INT_MAX - HEAL_INT_MIN) * f

        local amount = nz(missing * missPct, 0.0) + nz(INT * intPart, 0.0)
        local gained = healUnit(u, amount)

        playFX(FX_RELEASE_BLOOM, GetUnitX(u), GetUnitY(u))
        ownerPrint(u, "+" .. tostring(math.floor(gained + 0.5)) .. " HP (Burst " .. string.format("%.2f", f * CHANNEL_MAX_SEC) .. "s)")

        -- Optional armor buff via ModifierSystem (if available)
        if ARMOR_BONUS > 0 and _G.ModifierSystem and ModifierSystem.Apply then
            pcall(ModifierSystem.Apply, u, ARMOR_KEY, { amount = ARMOR_BONUS, duration = ARMOR_DUR })
        end
    end

    -----------------------------
    -- WIRING
    -----------------------------
    local function hasAbility(u, abil) return GetUnitAbilityLevel(u, abil) > 0 end

    local function hook()
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            local p = Player(i)
            TriggerRegisterPlayerUnitEvent(t, p, EVENT_PLAYER_HERO_SKILL, nil)
            TriggerRegisterPlayerUnitEvent(t, p, EVENT_PLAYER_UNIT_SPELL_CHANNEL, nil)
            TriggerRegisterPlayerUnitEvent(t, p, EVENT_PLAYER_UNIT_SPELL_FINISH, nil)
            TriggerRegisterPlayerUnitEvent(t, p, EVENT_PLAYER_UNIT_SPELL_ENDCAST, nil)
            TriggerRegisterPlayerUnitEvent(t, p, EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        end
        TriggerAddAction(t, function()
            local ev = GetTriggerEventId()
            local u  = GetTriggerUnit()

            if ev == EVENT_PLAYER_HERO_SKILL then
                local id = GetLearnedSkill()
                if id == ABIL_ID and hasAbility(u, ABIL_ID) then
                    track(u)
                end
                return
            end

            local id = GetSpellAbilityId()
            if id ~= ABIL_ID then return end

            if ev == EVENT_PLAYER_UNIT_SPELL_CHANNEL then
                startChannel(u)
            elseif ev == EVENT_PLAYER_UNIT_SPELL_FINISH then
                finishChannel(u)
            elseif ev == EVENT_PLAYER_UNIT_SPELL_ENDCAST then
                finishChannel(u)
            elseif ev == EVENT_PLAYER_UNIT_SPELL_EFFECT then
                track(u)
            end
        end)
    end

    OnInit.final(function()
        hook()
        print("[Regeneration] Ready (A02F; passive + channel burst + debug + ModifierSystem-safe)")
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
