if Debug and Debug.beginFile then Debug.beginFile("Spell_SoulBurst.lua") end
--==================================================
-- Lost Soul: Soul Burst (instant self-centered AoE)
-- Rawcode: A002
--==================================================

if not Spell_SoulBurst then Spell_SoulBurst = {} end
_G.Spell_SoulBurst = Spell_SoulBurst

do
    --------------------------------------------------
    -- CONFIG
    --------------------------------------------------
    local RAW_ID         = FourCC('A002')
    local RADIUS         = 300.0
    local BASE_DAMAGE    = 35.0
    local K_PER_POWER    = 0.015
    local FX_PRESET_ID   = "fx_soul_burst"

    local TARGET_FILTERS = {
        structures   = false,
        invulnerable = false,
        alive        = true,
        enemyOnly    = true,
    }

    --------------------------------------------------
    -- HELPERS
    --------------------------------------------------
    local function EnsureFXPreset()
        local FX = rawget(_G, "FX")
        if not FX or not FX.def then return end
        if not FX._hasSoulBurst then
            FX.def(FX_PRESET_ID, {
                sfx      = "war3mapImported\\blue spark by deckai2.mdl",
                where    = "ground",
                scale    = 1.10,
                life     = 0.0,
                camShake = 2.0,
            })
            FX._hasSoulBurst = true
        end
    end

    local function GetPowerLevel(pid)
        local HSS = rawget(_G, "HeroStatSystem")
        if HSS and HSS.GetPowerLevel then
            local v = HSS.GetPowerLevel(pid)
            if type(v) == "number" then return v end
        end
        -- fallback to PlayerData.powerLevel if present
        if _G.PlayerData and PlayerData[pid] and type(PlayerData[pid].powerLevel)=="number" then
            return PlayerData[pid].powerLevel
        end
        return 0
    end

    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function IsValidTarget(caster, u)
        if not ValidUnit(u) then return false end
        if TARGET_FILTERS.enemyOnly and IsPlayerAlly(GetOwningPlayer(u), GetOwningPlayer(caster)) then return false end
        if TARGET_FILTERS.alive and GetWidgetLife(u) <= 0.405 then return false end
        if not TARGET_FILTERS.structures and IsUnitType(u, UNIT_TYPE_STRUCTURE) then return false end
        if not TARGET_FILTERS.invulnerable and BlzIsUnitInvulnerable(u) then return false end
        return true
    end

    local function ApplyBurstDamage(caster, damage)
        local de = rawget(_G, "DamageEngine")
        local x  = GetUnitX(caster)
        local y  = GetUnitY(caster)

        local g = CreateGroup()
        GroupEnumUnitsInRange(g, x, y, RADIUS, nil)
        ForGroup(g, function()
            local u = GetEnumUnit()
            if IsValidTarget(caster, u) then
                if de and de.applySpellDamage then
                    de.applySpellDamage(caster, u, damage, DAMAGE_TYPE_MAGIC)
                else
                    UnitDamageTarget(caster, u, damage, false, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC, 0)
                end
            end
        end)
        DestroyGroup(g)
    end

    local function PlayFX(caster)
        local FX = rawget(_G, "FX")
        if FX and FX.play then
            FX.play(FX_PRESET_ID, { unit = caster, localTo = GetOwningPlayer(caster) })
        end
    end

    --------------------------------------------------
    -- PUBLIC CAST (used by CustomSpellBar runner)
    --------------------------------------------------
    function Spell_SoulBurst.Cast(caster)
        if not ValidUnit(caster) then return end
        local pid   = GetPlayerId(GetOwningPlayer(caster))
        local power = PlayerData.GetPowerLevel(pid)
        local dmg   = BASE_DAMAGE + (K_PER_POWER * power)
        ApplyBurstDamage(caster, dmg)
        PlayFX(caster)
        return true
    end

    --------------------------------------------------
    -- NORMAL ABILITY CAST HOOK (if pressed via stock UI)
    --------------------------------------------------
    OnInit.final(function()
        EnsureFXPreset()

        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        end
        TriggerAddAction(t, function()
            if GetSpellAbilityId() == RAW_ID then
                local caster = GetTriggerUnit()
                local ok = pcall(function() Spell_SoulBurst.Cast(caster) end)
                -- swallow errors; debug utils (if present) will log
            end
        end)

        -- dev chat: -testsoulburst
        local chat = CreateTrigger()
        for i = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerChatEvent(chat, Player(i), "-testsoulburst", true)
        end
        TriggerAddAction(chat, function()
            local p   = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            local u   = (PlayerData and PlayerData[pid] and PlayerData[pid].hero) or nil
            if ValidUnit(u) then
                Spell_SoulBurst.Cast(u)
            else
                DisplayTextToPlayer(p, 0, 0, "[SoulBurst] No hero found.")
            end
        end)

        if Log and Color then Log("Spell_SoulBurst", Color.GREEN, "ready (A002)") else
            print("[Spell_SoulBurst] ready (A002)")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
