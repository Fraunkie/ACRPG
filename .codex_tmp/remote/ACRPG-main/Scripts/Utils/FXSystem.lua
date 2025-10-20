if Debug and Debug.beginFile then Debug.beginFile("FXSystem.lua") end
--==================================================
-- FXSystem.lua  Minimal visual toolkit
--==================================================

FX = FX or {}
_G.FX = FX

do
    local defs = {}
    local casterTypeResolver = function(u) return "Generic" end

    function FX.def(name, data)
        defs[name] = data
    end

    function FX.setCasterTypeResolver(fn)
        if type(fn) == "function" then casterTypeResolver = fn end
    end

    local function localOnly(player, fn)
        if GetLocalPlayer() == player then
            fn()
        end
    end

    local function playPreset(preset, ctx)
        if not preset then return end
        local data = preset
        if type(preset) == "string" then
            data = defs[preset]
        end
        if not data then return end

        local owner = ctx and ctx.localTo
        local unit  = ctx and ctx.unit
        local x     = ctx and ctx.x
        local y     = ctx and ctx.y
        local scale = data.scale or 1.0

        if data.sound then
            localOnly(owner or GetLocalPlayer(), function()
                StartSound(CreateSound(data.sound, false, false, false, 10, 10, ""))
            end)
        end

        if unit and (data.where == "attach") then
            local eff = AddSpecialEffectTarget(data.sfx, unit, data.attach or "origin")
            BlzSetSpecialEffectScale(eff, scale)
            if data.life and data.life > 0 then
                TimerStart(CreateTimer(), data.life, false, function()
                    DestroyEffect(eff)
                    DestroyTimer(GetExpiredTimer())
                end)
            end
        else
            local px = x or (unit and GetUnitX(unit)) or 0
            local py = y or (unit and GetUnitY(unit)) or 0
            local eff = AddSpecialEffect(data.sfx, px, py)
            BlzSetSpecialEffectScale(eff, scale)
            if data.life and data.life > 0 then
                TimerStart(CreateTimer(), data.life, false, function()
                    DestroyEffect(eff)
                    DestroyTimer(GetExpiredTimer())
                end)
            else
                DestroyEffect(eff)
            end
        end

        if data.camShake and owner then
            localOnly(owner, function()
                CameraSetSourceNoise(data.camShake, data.camShake)
                TimerStart(CreateTimer(), 0.25, false, function()
                    CameraSetSourceNoise(0, 0)
                    DestroyTimer(GetExpiredTimer())
                end)
            end)
        end

        if data.anim and unit then
            SetUnitAnimation(unit, data.anim)
        end
    end

    local function pickByCasterType(fx, caster)
        if type(fx) == "table" then
            local tag = casterTypeResolver(caster)
            return fx[tag] or fx.default
        end
        return fx
    end

    function FX.play(fx, ctx)
        if not fx then return end
        local chosen = pickByCasterType(fx, ctx and ctx.unit)
        local ok, _ = pcall(function() playPreset(chosen, ctx) end)
        if not ok then
            -- quiet failure
        end
    end

    -- stages is array of { t = fraction, fx = preset or keyed table, anim=..., camShake=... }
    function FX.timeline(stages, ctx, fractionNow, lastFraction)
        if not stages or not fractionNow then return end
        local lf = lastFraction or 0
        for i = 1, #stages do
            local s = stages[i]
            if s.t and lf < s.t and fractionNow >= s.t then
                local chosen = pickByCasterType(s.fx, ctx and ctx.unit)
                if chosen then FX.play(chosen, ctx) end
                if s.anim and ctx and ctx.unit then SetUnitAnimation(ctx.unit, s.anim) end
            end
        end
    end
end

OnInit.final(function()
    -- Define shared presets here so other systems can use them
    if FX and FX.def then
        -- Persistent aura for Soul Haste passive
        FX.def("fx_soul_haste_aura", {
            sfx    = "war3mapImported\\deco_7.mdx",
            where  = "attach",
            attach = "origin",
            scale  = 1.0
            -- no life field => persistent attach effect
        })
    end

    if Log and Color then Log("FXSystem", Color.CYAN, "ready") else print("[FXSystem] ready") end
end)

if Debug and Debug.endFile then Debug.endFile() end
