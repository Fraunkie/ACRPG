if Debug and Debug.beginFile then Debug.beginFile("Spell_Surge.lua") end
--==================================================
-- Surge Movement (A02E) — Smooth dash with afterimages
-- • Dash forward along facing over ~0.25s (stepwise SetUnitPosition)
-- • Invulnerable during dash (adds Avul if missing, removes after)
-- • Respects pathing blockers; stops early on collision
-- • Ignores units; leaves blue-tinted afterimages using DUMY
--==================================================

do
    local ABIL_ID        = FourCC('A02E')
    local DUMY_ID        = FourCC('DUMY')      -- your shapeshift dummy (Locust, no shadow)
    local INVUL_ABILITY  = FourCC('Avul')

    local DURATION       = 0.25                -- seconds
    local RANGE          = 600.0               -- units
    local TICK           = 0.03
    local SPEED          = RANGE / DURATION
    local MIN_STEP       = 6.0

    local TRAIL_PERIOD   = 0.05
    local TRAIL_LIFE     = 0.35                -- how long ghosts linger
    local TRAIL_ALPHA    = 150                 -- 0..255
    local TRAIL_TINT_R   = 150                 -- soft blue tint
    local TRAIL_TINT_G   = 200
    local TRAIL_TINT_B   = 255

    local FX_END         = "Abilities\\Spells\\Human\\DispelMagic\\DispelMagicTarget.mdl"

    local PT_WALK = PATHING_TYPE_WALKABILITY or ConvertPathingType(0)

    local timer, active = nil, {}

    local function unitAlive(u)
        return u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
    end
    local function pathable(x, y)
        return not IsTerrainPathable(x, y, PT_WALK)
    end
    local function playFX(model, x, y)
        local e = AddSpecialEffect(model, x, y)
        DestroyEffect(e)
    end

    local function tryStep(u, dx, dy, step)
        local ux, uy = GetUnitX(u), GetUnitY(u)
        local len = SquareRoot(dx*dx + dy*dy)
        if len < 0.001 then return ux, uy, 0.0 end
        local nx = ux + dx / len * step
        local ny = uy + dy / len * step
        if pathable(nx, ny) then
            SetUnitPosition(u, nx, ny)
            local ax, ay = GetUnitX(u), GetUnitY(u)
            local moved = SquareRoot((ax - ux)*(ax - ux) + (ay - uy)*(ay - uy))
            return ax, ay, moved
        end
        local s = step * 0.5
        while s >= MIN_STEP do
            nx = ux + dx / len * s
            ny = uy + dy / len * s
            if pathable(nx, ny) then
                SetUnitPosition(u, nx, ny)
                local ax, ay = GetUnitX(u), GetUnitY(u)
                local moved = SquareRoot((ax - ux)*(ax - ux) + (ay - uy)*(ay - uy))
                return ax, ay, moved
            end
            s = s * 0.5
        end
        return ux, uy, 0.0
    end

    local function endDash(s)
        if not s or s.ended then return end
        s.ended = true
        if s.invulAdded and GetUnitAbilityLevel(s.unit, INVUL_ABILITY) > 0 then
            UnitRemoveAbility(s.unit, INVUL_ABILITY)
        end
        playFX(FX_END, GetUnitX(s.unit), GetUnitY(s.unit))
    end

    local function tick()
        local i = 1
        while i <= #active do
            local s = active[i]
            if not s or not unitAlive(s.unit) then
                if s then endDash(s) end
                table.remove(active, i)
            else
                s.t = s.t + TICK
                s.trailT = s.trailT + TICK

                local step = SPEED * TICK
                local nx, ny, moved = tryStep(s.unit, s.dirX, s.dirY, step)

                -- Afterimage: mirror caster model on a blue-tinted DUMY
                if s.trailT >= TRAIL_PERIOD then
                    s.trailT = 0.0
                    local facing = GetUnitFacing(s.unit)
                    local ghost = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), DUMY_ID, nx, ny, facing)
                    
                    -- Prevent respawn and make unselectable
                    UnitAddType(ghost, UNIT_TYPE_DEAD)
                    SetUnitInvulnerable(ghost, true)
                    ShowUnit(ghost, true) -- Ensure visible
                    
                    -- Mirror appearance
                    local casterSkin = BlzGetUnitSkin(s.unit)
                    if casterSkin then
                        BlzSetUnitSkin(ghost, casterSkin)
                    end
                    SetUnitScale(ghost, 1.0, 1.0, 1.0)
                    SetUnitVertexColor(ghost, TRAIL_TINT_R, TRAIL_TINT_G, TRAIL_TINT_B, TRAIL_ALPHA)
                    UnitApplyTimedLife(ghost, FourCC('BTLF'), TRAIL_LIFE)
                end

                s.dist = s.dist + moved
                local finished = (s.t >= DURATION) or (s.dist >= RANGE) or (moved < MIN_STEP)

                if finished then
                    endDash(s)
                    table.remove(active, i)
                else
                    i = i + 1
                end
            end
        end
        if #active == 0 and timer then
            PauseTimer(timer)
        end
    end

    local function startDash(u)
        if not unitAlive(u) then return end
        local facing = GetUnitFacing(u) * bj_DEGTORAD
        local dirX, dirY = math.cos(facing), math.sin(facing)

        local hadInvul = GetUnitAbilityLevel(u, INVUL_ABILITY) > 0
        if not hadInvul then
            UnitAddAbility(u, INVUL_ABILITY)
        end

        local s = {
            unit       = u,
            dirX       = dirX,
            dirY       = dirY,
            t          = 0.0,
            dist       = 0.0,
            trailT     = 0.0,
            invulAdded = not hadInvul,
            ended      = false
        }
        table.insert(active, s)

        if not timer then timer = CreateTimer() end
        TimerStart(timer, TICK, true, tick)
    end

    local function onCast(ctx)
        startDash(ctx.caster)
    end

    OnInit.final(function()
        if _G.SpellEngine and SpellEngine.RegisterScripted then
            SpellEngine.RegisterScripted(ABIL_ID, onCast)
        else
            local t = CreateTrigger()
            for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
                TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
            end
            TriggerAddAction(t, function()
                if GetSpellAbilityId() == ABIL_ID then
                    startDash(GetTriggerUnit())
                end
            end)
        end
        print("[Surge] Ready (mirror afterimages)")
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
