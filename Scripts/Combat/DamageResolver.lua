if Debug and Debug.beginFile then Debug.beginFile("DamageResolver.lua") end
--==================================================
-- DamageResolver.lua
-- Applies dodge, parry, block, crit, armor, energy resist.
-- Energy damage == Magic damage (anime/DB style).
-- API:
--   DamageResolver.Resolve(ctx) -> { amount, result, isCrit }
-- Uses StatSystem first; falls back to PlayerData if needed.
-- Also: if DamageEngine.showCombatResultText exists, we show
--       CRIT / BLOCK / DODGE / PARRY tags right here, AFTER
--       we know the final outcome.
--==================================================

if not DamageResolver then DamageResolver = {} end
_G.DamageResolver = DamageResolver

do
    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function ValidUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function rnd()
        return GetRandomReal(0.0, 1.0)
    end

    local function clamp01(x)
        if x < 0 then return 0 end
        if x > 1 then return 1 end
        return x
    end

    local function GB(key, def)
        local GB = rawget(_G, "GameBalance")
        if GB and GB[key] ~= nil then
            return GB[key]
        end
        return def
    end

    local BASE_CRIT_MULT  = GB("CRIT_MULT_BASE", 1.5)
    local BLOCK_REDUCTION = GB("BLOCK_REDUCTION", 0.30)

    -- classify: default to Physical for basic attacks, Energy otherwise
    local function isEnergyHit(ctx)
        if ctx == nil then
            return false
        end
        if ctx.isAttack == true then
            return false
        end
        -- You can tag specific spells later to force Energy true.
        return true
    end

    local function armorMitigate(amt, armor)
        if armor <= 0 then
            return amt
        end
        return amt * (100.0 / (100.0 + armor))
    end

    local function resistMitigate(amt, resist)
        if resist <= 0 then
            return amt
        end
        return amt * (100.0 / (100.0 + resist))
    end

    -- Read stats with StatSystem preferred, PlayerData fallback
    local function getStats(src, tgt)
        local SS = rawget(_G, "StatSystem")
        local PD = rawget(_G, "PlayerData")

        local function pidOf(u)
            local p = GetOwningPlayer(u)
            if not p then
                return nil
            end
            return GetPlayerId(p)
        end

        local srcPid = src and pidOf(src) or nil
        local tgtPid = tgt and pidOf(tgt) or nil

        local armor = 0
        local eres  = 0
        local dodge = 0
        local parry = 0
        local block = 0
        local critC = 0
        local critM = BASE_CRIT_MULT

        if SS then
            if SS.GetArmor        and tgt then armor = SS.GetArmor(tgt) or armor end
            if SS.GetEnergyResist and tgt then eres  = SS.GetEnergyResist(tgt) or eres end
            if SS.GetMagicResist  and tgt and eres == 0 then eres = SS.GetMagicResist(tgt) or 0 end
            if SS.GetDodge        and tgt then dodge = SS.GetDodge(tgt) or dodge end
            if SS.GetParry        and tgt then parry = SS.GetParry(tgt) or parry end
            if SS.GetBlock        and tgt then block = SS.GetBlock(tgt) or block end
            if SS.GetCrit         and src then critC = SS.GetCrit(src) or critC end
            if SS.GetCritMult     and src then critM = SS.GetCritMult(src) or critM end
        end

        if PD then
            if tgtPid ~= nil then
                if armor == 0 and PD.GetArmor then
                    armor = PD.GetArmor(tgtPid) or armor
                end
                if eres == 0 and PD.GetEnergyResist then
                    eres = PD.GetEnergyResist(tgtPid) or eres
                end
                if dodge == 0 and PD.GetDodge then
                    dodge = PD.GetDodge(tgtPid) or dodge
                end
                if parry == 0 and PD.GetParry then
                    parry = PD.GetParry(tgtPid) or parry
                end
                if block == 0 and PD.GetBlock then
                    block = PD.GetBlock(tgtPid) or block
                end
            end
            if srcPid ~= nil then
                if critC == 0 and PD.GetCrit then
                    critC = PD.GetCrit(srcPid) or critC
                end
                if (not critM or critM <= 1.0) and PD.GetCritMult then
                    critM = PD.GetCritMult(srcPid) or critM
                end
            end
        end

        return {
            armor  = math.max(0, math.floor(armor or 0)),
            eres   = math.max(0, math.floor(eres or 0)),
            dodge  = clamp01(dodge or 0),
            parry  = clamp01(parry or 0),
            block  = clamp01(block or 0),
            critC  = clamp01(critC or 0),
            critM  = (critM and critM > 1.0) and critM or BASE_CRIT_MULT,
        }
    end

    --------------------------------------------------
    -- Resolve
    --------------------------------------------------
    function DamageResolver.Resolve(ctx)
        -- ctx = { source, target, amount, isAttack, ... }
        if not ctx or not ValidUnit(ctx.target) then
            return {
                amount = ctx and ctx.amount or 0,
                result = "HIT",
                isCrit = false
            }
        end

        local src = ctx.source
        local tgt = ctx.target
        local amt = tonumber(ctx.amount or 0) or 0
        if amt <= 0 then
            return { amount = 0, result = "HIT", isCrit = false }
        end

        local st = getStats(src, tgt)

        -- Avoidance (priority: dodge > parry > block)
        if rnd() < st.dodge then
            ctx.result = "DODGE"
            if DamageEngine and DamageEngine.showCombatResultText then
                DamageEngine.showCombatResultText(tgt, "DODGE")
            end
            return { amount = 0, result = "DODGE", isCrit = false }
        end

        if rnd() < st.parry then
            ctx.result = "PARRY"
            if DamageEngine and DamageEngine.showCombatResultText then
                DamageEngine.showCombatResultText(tgt, "PARRY")
            end
            return { amount = 0, result = "PARRY", isCrit = false }
        end

        local didBlock = false
        if rnd() < st.block then
            didBlock = true
            amt = amt * (1.0 - BLOCK_REDUCTION)
            ctx.result = "BLOCK"
        end

        -- Mitigation: Energy uses energy resist; Physical uses armor
        if isEnergyHit(ctx) then
            amt = resistMitigate(amt, st.eres)
            ctx.isEnergy   = true
            ctx.isPhysical = false
        else
            amt = armorMitigate(amt, st.armor)
            ctx.isEnergy   = false
            ctx.isPhysical = true
        end

        -- Crit (allowed on both)
        local didCrit = false
        if amt > 0 and rnd() < st.critC then
            amt = amt * st.critM
            didCrit = true
            if ctx.result ~= "BLOCK" then
                ctx.result = "CRIT"
            end
        end

        if amt < 0 then
            amt = 0
        end

        if ctx.result ~= "BLOCK" and not didCrit then
            ctx.result = "HIT"
        end

        -- Show outcome tag here (only if not just HIT)
        if DamageEngine and DamageEngine.showCombatResultText and ctx.result and ctx.result ~= "HIT" then
            DamageEngine.showCombatResultText(tgt, ctx.result)
        end

        return {
            amount = amt,
            result = ctx.result,
            isCrit = didCrit
        }
    end
end

if Debug and Debug.endFile then Debug.endFile() end
