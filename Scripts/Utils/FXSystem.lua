if Debug and Debug.beginFile then Debug.beginFile("FXSystem.lua") end
--==================================================
-- FXSystem.lua  (compat layer + simple FX helpers)
--  - Supports your existing calls:
--      FXSystem.AttachUnit(unit, attachPoint, { model=..., scale=..., life=... })
--      FXSystem.Destroy(effectHandle)
--  - Also exposes a small preset system:
--      FX.def(name, dataTable)   -- or FXSystem.def(...)
--      FX.play(fxOrName, ctx)    -- or FXSystem.play(...)
--      FX.timeline(stages, ctx, nowFrac, lastFrac)
--==================================================

-- Single internal module table
local M = {}
_G.FX = _G.FX or M           -- legacy/global alias
_G.FXSystem = _G.FXSystem or M

do
    --------------------------------------------------
    -- Registry and basic config
    --------------------------------------------------
    local defs = {}                       -- name -> preset table
    local casterTypeResolver = function(u) return "Generic" end

    function M.def(name, data)            -- define or overwrite a preset
        if name and data then defs[name] = data end
    end

    function M.setCasterTypeResolver(fn)  -- optional discriminator for class-based fx tables
        if type(fn) == "function" then casterTypeResolver = fn end
    end

    --------------------------------------------------
    -- Internals
    --------------------------------------------------
    local function localOnly(player, thunk)
        if player and GetLocalPlayer() ~= player then return end
        thunk()
    end

    local function pickByCasterType(fx, caster)
        if type(fx) == "table" and (fx.sfx == nil) then
            -- keyed by caster type; expect a field "default" as fallback
            local tag = casterTypeResolver(caster)
            return fx[tag] or fx.default
        end
        return fx
    end

    local function playPreset(preset, ctx)
        -- preset fields (all optional):
        --  sfx, where("attach" | nil), attach("origin"...), scale, life, sound, camShake, anim
        if not preset then return end
        local data = preset
        if type(preset) == "string" then data = defs[preset] end
        if not data then return end

        local owner = ctx and ctx.localTo     -- Player handle to restrict locally (optional)
        local unit  = ctx and ctx.unit
        local x     = (ctx and ctx.x) or (unit and GetUnitX(unit)) or 0
        local y     = (ctx and ctx.y) or (unit and GetUnitY(unit)) or 0
        local scale = data.scale or 1.0

        if data.sound then
            localOnly(owner or GetLocalPlayer(), function()
                local s = CreateSound(data.sound, false, false, false, 10, 10, "")
                StartSound(s)
            end)
        end

        local eff
        if unit and data.where == "attach" then
            eff = AddSpecialEffectTarget(data.sfx, unit, data.attach or "origin")
        else
            eff = AddSpecialEffect(data.sfx, x, y)
        end
        if scale and scale ~= 1.0 then BlzSetSpecialEffectScale(eff, scale) end

        if data.life and data.life > 0 then
            local t = CreateTimer()
            TimerStart(t, data.life, false, function()
                DestroyEffect(eff)
                DestroyTimer(t)
            end)
        end

        if data.camShake and owner then
            localOnly(owner, function()
                CameraSetSourceNoise(data.camShake, data.camShake)
                local t = CreateTimer()
                TimerStart(t, 0.25, false, function()
                    CameraSetSourceNoise(0, 0)
                    DestroyTimer(t)
                end)
            end)
        end

        if data.anim and unit then
            SetUnitAnimation(unit, data.anim)
        end

        return eff
    end

    --------------------------------------------------
    -- Public: play / timeline
    --------------------------------------------------
    function M.play(fx, ctx)
        local chosen = pickByCasterType(fx, ctx and ctx.unit)
        local ok, res = pcall(function() return playPreset(chosen, ctx) end)
        if ok then return res end
        return nil
    end

    -- stages: array of { t=fraction, fx=presetOrKeyed, anim=..., camShake=... }
    function M.timeline(stages, ctx, nowFrac, lastFrac)
        if not stages or not nowFrac then return end
        local lf = lastFrac or 0
        for i = 1, #stages do
            local s = stages[i]
            if s.t and lf < s.t and nowFrac >= s.t then
                local chosen = pickByCasterType(s.fx, ctx and ctx.unit)
                if chosen then M.play(chosen, ctx) end
                if s.anim and ctx and ctx.unit then SetUnitAnimation(ctx.unit, s.anim) end
            end
        end
    end

    --------------------------------------------------
    -- Compatibility helpers expected by other code
    --  FXSystem.AttachUnit / FXSystem.Destroy
    --------------------------------------------------
    function M.AttachUnit(unit, attachPoint, opt)
        if not unit then return nil end
        local mdl   = (opt and opt.model) or "Abilities\\Spells\\Items\\AIlb\\AIlbTarget.mdl"
        local point = attachPoint or "origin"
        local e = AddSpecialEffectTarget(mdl, unit, point)
        if opt and opt.scale then BlzSetSpecialEffectScale(e, opt.scale) end
        -- opt.life > 0 -> auto destroy after life seconds
        if opt and opt.life and opt.life > 0 then
            local t = CreateTimer()
            TimerStart(t, opt.life, false, function()
                DestroyEffect(e)
                DestroyTimer(t)
            end)
        end
        return e
    end

    function M.Destroy(eff)
        if eff then DestroyEffect(eff) end
    end

    --------------------------------------------------
    -- Aliases so both FX and FXSystem expose the same API
    --------------------------------------------------
    -- (Nothing else required; _G.FX and _G.FXSystem already point to M)
end

-- Optional: define a shared preset other modules can reuse
OnInit.final(function()
    if FX and FX.def then
        FX.def("fx_soul_haste_aura", {
            sfx    = "war3mapImported\\deco_7.mdx",
            where  = "attach",
            attach = "origin",
            scale  = 1.0
            -- no life -> persistent until destroyed
        })
    end
end)

if Debug and Debug.endFile then Debug.endFile() end
