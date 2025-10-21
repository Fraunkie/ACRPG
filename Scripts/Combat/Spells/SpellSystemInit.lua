if Debug and Debug.beginFile then Debug.beginFile("SpellSystemInit.lua") end
--==================================================
-- Spell System (Data Layer) with damage calculator
--==================================================

if not SpellSystemInit then SpellSystemInit = {} end
_G.SpellSystemInit = SpellSystemInit

-- Optional visuals used by charging/launch (kept for other spells)
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

----------------------------------------------------
-- Core spell data table
----------------------------------------------------
local SpellData = {
    --============== Lost Soul kit (examples) ==============

    -- A000: passive attack speed (ModifierSystem reads this)
    [FourCC('A000')] = {
        name  = "Soul Acceleration",
        type  = "passive",
        attackSpeedMult = 2.20,
        auraModel       = "war3mapImported\\BJT_Shio_SYR_FX_QL.mdx"
    },

    -- A002: instant AoE burst around the caster
    [FourCC('A002')] = {
        name = "Soul Burst",
        type = "instant_aoe",
        damageBase = 60.0,
        intScale   = 1.50,
        aoe        = 250.0,
        fxModel    = "war3mapImported\\blue spark by deckai2.mdl",
        mana       = 0,
        cooldown   = 0
    },

    -- A003: on-hit magic damage passive (melee proc)
    [FourCC('A003')] = {
        name = "Planar Echo",
        type = "passive_onhit",
        bonusBase = 25.0,
        intScale  = 0.40,
        fxModel   = nil
    },

    --================== Beams/Balls (examples) ==================
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

----------------------------------------------------
-- Damage Calculator
-- INT * K  ->  multiplied by (1 + spellBonusPct + externalBonusPct)
----------------------------------------------------
local INT_FACTOR = 1.00  -- tweak this global scalar to retune overall spell power

local function getInt(pid)
    return (rawget(_G, "PlayerMInt") and PlayerMInt[pid]) or 0
end

local function getSpellBonusPct(pid)
    -- primary source: PLAYER_DATA.combat.spellBonusPct
    local v = (PLAYER_DATA and PLAYER_DATA[pid]
        and PLAYER_DATA[pid].combat and PLAYER_DATA[pid].combat.spellBonusPct) or 0.0
    -- secondary source (optional): StatSystem if you have one
    if _G.StatSystem and StatSystem.GetSpellBonusPct then
        local ext = StatSystem.GetSpellBonusPct(pid)
        if type(ext) == "number" then
            v = v + ext
        end
    end
    return v
end

-- Public: compute damage for a configured spell
function SpellSystemInit.GetDamageForSpell(pid, spellKey, spellLevel, ctx)
    local cfg = SpellData[spellKey]
    if not cfg then return 0 end

    -- If a spell provides its own calc, use that
    if type(cfg.calc) == "function" then
        local ok, v = pcall(cfg.calc, pid, spellLevel or 1, ctx or {})
        if ok and type(v) == "number" then return math.max(0, v) end
    end

    -- Generic fallback: base + per level, then apply INT scaling & spell bonus
    local base = (cfg.damageBase or 0) + math.max(0, (spellLevel or 1) - 1) * (cfg.damagePerLevel or 0)
    local int  = getInt(pid)
    local bonusPct = getSpellBonusPct(pid)

    local raw = (base + int * INT_FACTOR)
    return math.max(0, raw * (1.0 + bonusPct))
end

-- Back-compat shim (older code calls this)
function SpellSystemInit.GetScaledDamage(playerId, spellKey, spellLevel)
    return SpellSystemInit.GetDamageForSpell(playerId, spellKey, spellLevel, nil)
end

-- Expose config lookups
function SpellSystemInit.GetSpellConfig(spellKey)
    return SpellData[spellKey]
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
