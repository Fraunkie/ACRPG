if Debug and Debug.beginFile then Debug.beginFile("SpellSystemInit.lua") end
--==================================================
-- Spell System (Data Layer) with charge schema
--==================================================

if not SpellSystemInit then SpellSystemInit = {} end
_G.SpellSystemInit = SpellSystemInit

-- Optional visuals used by stages or launch
if FX and FX.def then
    FX.def("SPARK_SMALL", {
        sfx="Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl",
        where="attach", attach="hand right", scale=1.0, life=0.0
    })
    FX.def("SAIYAN_CRACKLE", {
        sfx="Abilities\\Spells\\Other\\Monsoon\\MonsoonBoltTarget.mdl",
        where="attach", attach="origin", scale=1.1
    })
    FX.def("LAUNCH_FLASH", {
        sfx="Abilities\\Spells\\Other\\Incinerate\\FireLordDeathExplode.mdl",
        where="ground", scale=1.0
    })
end

local SpellData = {
    --========================
    -- NEW: Lost Soul kit
    --========================

    -- A000: passive attack speed (used by ModifierSystem)
    [FourCC('A000')] = {
        name  = "Soul Acceleration",
        type  = "passive",
        -- 120% total AS = 2.20 multiplier (1.0 base + 1.2 extra)
        attackSpeedMult = 2.20,
        auraModel       = "war3mapImported\\BJT_Shio_SYR_FX_QL.mdx"
    },

    -- A002: instant AoE burst around the caster
    [FourCC('A002')] = {
        name = "Soul Burst",
        type = "instant_aoe",
        damageBase = 60.0,         -- flat base
        intScale   = 1.50,         -- + INT * 1.5 (the executor uses this)
        aoe        = 250.0,
        fxModel    = "war3mapImported\\blue spark by deckai2.mdl",
        mana       = 0,
        cooldown   = 0
    },

    -- A003: on-hit magic damage passive (your melee proc)
    [FourCC('A003')] = {
        name = "Planar Echo",
        type = "passive_onhit",
        bonusBase = 25.0,          -- flat on-hit magic
        intScale  = 0.40,          -- + INT * 0.40
        fxModel   = nil            -- visual handled by proc if you add one
    },

    --========================
    -- Existing beam/ball examples
    --========================
    [FourCC('A006')] = {
        name = "Kamehameha",
        type = "beam",
        damageBase = 150.0,
        damagePerLevel = 50.0,
        range = 1000.0,
        projectileUnit = FourCC('e001'),
        trailUnit      = FourCC('e001'),
        mana           = 0,
        speed          = 1000.0,
        collision      = 120.0,
        hitModel       = "Abilities\\Spells\\Other\\Incinerate\\FireLordDeathExplode.mdl",
        charge = { enabled=false }
    },

    [FourCC('A01W')] = {
        name = "Galick Gun",
        type = "beam",
        damageBase = 150.0,
        damagePerLevel = 50.0,
        range = 1000.0,
        projectileUnit = FourCC('e00B'),
        trailUnit      = FourCC('e00B'),
        mana           = 0,
        speed          = 1000.0,
        collision      = 120.0,
        hitModel       = "Abilities\\Spells\\Other\\Incinerate\\FireLordDeathExplode.mdl",
        charge = { enabled=false }
    },

    [FourCC('A020')] = {
        name = "Final Flash",
        type = "beam",
        damageBase = 250.0,
        damagePerLevel = 80.0,
        range = 1500.0,
        aoeRange = 250.0,
        cooldown = 25.0,
        channelTime = 4.0,
        projectileUnit = FourCC('e00C'),
        trailUnit      = FourCC('e00C'),
        charge = { enabled=false }
    },

    [FourCC('A01X')] = {
        name = "Big Bang Attack",
        type = "ball",
        damageBase = 300.0,
        damagePerLevel = 100.0,
        range = 1200.0,
        aoeRange = 300.0,
        cooldown = 10.0,
        projectileUnit = FourCC('e00K'),
        speed          = 900.0,
        collision      = 140.0,
        hitModel       = "Abilities\\Spells\\Other\\Incinerate\\FireLordDeathExplode.mdl",

        charge = {
            enabled    = true,
            headGrow   = true,
            maxTime    = 3.0,
            multFrom   = 0.60,
            multTo     = 2.50,
            sizeFrom   = 0.85,
            sizeTo     = 3.20,
            speedBoost = 0.15,
            uiBar      = true,
            stages = {
                { t=0.25, fx={ default="SPARK_SMALL", Saiyan="SAIYAN_CRACKLE" }, anim="spell" },
                { t=0.50, fx="SPARK_SMALL" },
                { t=0.90, fx="SAIYAN_CRACKLE", camShake=0.07 },
            }
        },

        ball = {
            holdOffset = { x = 50.0, y = 0.0 }
        }
    }
}

function SpellSystemInit.GetSpellConfig(spellKey)
    return SpellData[spellKey]
end

function SpellSystemInit.GetScaledDamage(playerId, spellKey, spellLevel)
    local cfg = SpellData[spellKey]
    if not cfg then return 0 end

    local damage = (cfg.damageBase or 0)
        + ((cfg.damagePerLevel or 0) * math.max((spellLevel or 1) - 1, 0))

    if PLAYER_DATA and PLAYER_DATA[playerId] then
        local power = PLAYER_DATA[playerId].powerLevel or 0
        damage = damage + (power * 0.2)
    end
    if StatSystem and StatSystem.GetDamageBonus then
        local mult = StatSystem.GetDamageBonus(playerId)
        if mult and mult > 0 then
            damage = damage * mult
        end
    end
    return damage
end

local function tablelength(tbl)
    local c = 0
    for _ in pairs(tbl) do c = c + 1 end
    return c
end

OnInit.final(function()
    print("|cffffcc00[SpellSystemInit]|r Loaded " .. tostring(tablelength(SpellData)) .. " spells.")
end)

if Debug and Debug.endFile then Debug.endFile() end
