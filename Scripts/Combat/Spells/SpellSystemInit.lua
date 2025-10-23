if Debug and Debug.beginFile then Debug.beginFile("SpellSystemInit.lua") end
--==================================================
-- Spell System (Data Layer) with damage calculator
--==================================================

if not SpellSystemInit then SpellSystemInit = {} end
_G.SpellSystemInit = SpellSystemInit

----------------------------------------------------
-- Optional shared FX presets
----------------------------------------------------
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
    --------------------------------------------------
    -- GOKU: Energy Bounce (Scripted)
    --------------------------------------------------
    [FourCC('A0EB')] = {
        name         = "Energy Bounce",
        type         = "scripted",
        damageBase   = 100.0,         -- Base damage like Kamehameha
        damagePerLevel = 25.0,        -- Per level scaling
        intScale     = 0.9,           -- INT scaling factor
        projectileUnit = FourCC('e001'),
        range        = 800.0,
        maxBounces   = 3,
        searchRadius = 600.0,
        falloffPct   = 0.15,
        fxHit        = "Abilities\\Spells\\Human\\DispelMagic\\DispelMagicTarget.mdl",
        hitSound     = "Abilities\\Spells\\Other\\Monsoon\\MonsoonLightningHit1.wav"
    },

    --------------------------------------------------
    -- PICCOLO: Stretch Limb (Scripted)
    -- Hand leads, arm segments trail. Prioritize enemies; if none, ally jump.
    -- Low damage; primary CC = short stun, plus small self-pull on enemy hit.
    --------------------------------------------------
    [FourCC('A2PS')] = {
        name           = "Stretch Limb",
        type           = "scripted",

        -- Core tuning
        range          = 700.0,
        collision      = 70.0,           -- hand hit radius
        stunDur        = 0.75,           -- base stun vs enemies (Modifier system)
        pullSelf       = 120.0,          -- Piccolo pulls toward enemy on hit
        allowAllyJump  = true,           -- ally dash allowed only if no enemy is hit
        allyStop       = 100.0,          -- stop short of ally on jump

        -- Visual models (hand leads, arm trails)
        models = {
            hand = "war3mapImported\\SlappyHand.mdx",
            arm  = "war3mapImported\\SlappyArm.mdx"
        },

        -- Damage: unified + low (chip only)
        damageBase     = 35.0,
        damagePerLevel = 10.0,

        -- Custom calc to use a unified "main stat" scale (0.30)
        calc = function(pid, lvl, ctx)
            local level = lvl or 1
            local base  = 35 + math.max(0, level - 1) * 10
            local main  = 0

            if _G.StatSystem and StatSystem.GetMainStat then
                local ok, v = pcall(StatSystem.GetMainStat, pid)
                if ok and type(v) == "number" then main = v end
            else
                local str = (rawget(_G, "PlayerMStr") and PlayerMStr[pid]) or 0
                local int = (rawget(_G, "PlayerMInt") and PlayerMInt[pid]) or 0
                if str > int then main = str else main = int end
            end

            local scaled = base + main * 0.30

            local bonusPct = 0.0
            if _G.StatSystem and StatSystem.GetSpellBonusPct then
                local ok2, b = pcall(StatSystem.GetSpellBonusPct, pid)
                if ok2 and type(b) == "number" then
                    bonusPct = bonusPct + b
                end
            end
            return math.max(0, scaled * (1.0 + bonusPct))
        end,

        -- UI knobs (kept here for reference; your UI may read these)
        cooldown = 7.0,
        mana     = 20.0,
    },

    --------------------------------------------------
    -- Existing examples (Kept)
    --------------------------------------------------
    [FourCC('A000')] = {
        name  = "Soul Acceleration",
        type  = "passive",
        attackSpeedMult = 2.20,
        auraModel       = "war3mapImported\\BJT_Shio_SYR_FX_QL.mdx"
    },

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

    [FourCC('A003')] = {
        name = "Planar Echo",
        type = "passive_onhit",
        bonusBase = 25.0,
        intScale  = 0.40,
        fxModel   = nil
    },

        --------------------------------------------------
    -- PICCOLO: Light Pulse
    --------------------------------------------------
    [FourCC('A0LG')] = {
        name           = "Light Pulse",
        type           = "scripted",
        damageBase     = 100.00,          -- handled dynamically (INT-based)
        intScale       = 0.70,       -- matches DMG_INT_MULT
        healScale      = 0.40,       -- initial heal scale (INT * 0.4)
        hotScale       = 0.10,       -- lingering heal per tick (INT * 0.1)
        radius         = 300.0,
        lingerTime     = 1.50,
        fxBurst        = "Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl",
        fxLinger       = "Abilities\\Spells\\Other\\ImmolationRed\\ImmolationRedTarget.mdl",
        cooldown       = 12.0,
        description    = "Emits a burst of Namekian light that heals allies and damages enemies within 300 range, leaving a brief healing aura.",
    },


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

        ball = { holdOffset = { x = 50.0, y = 0.0 } }
    }
}

----------------------------------------------------
-- Damage Calculator
----------------------------------------------------
local INT_FACTOR = 1.00

local function getInt(pid)
    return (rawget(_G, "PlayerMInt") and PlayerMInt[pid]) or 0
end

local function getSpellBonusPct(pid)
    local v = (PLAYER_DATA and PLAYER_DATA[pid]
        and PLAYER_DATA[pid].combat and PLAYER_DATA[pid].combat.spellBonusPct) or 0.0
    if _G.StatSystem and StatSystem.GetSpellBonusPct then
        local ext = StatSystem.GetSpellBonusPct(pid)
        if type(ext) == "number" then
            v = v + ext
        end
    end
    return v
end

function SpellSystemInit.GetDamageForSpell(pid, spellKey, spellLevel, ctx)
    local cfg = SpellData[spellKey]
    if not cfg then return 0 end

    if type(cfg.calc) == "function" then
        local ok, v = pcall(cfg.calc, pid, spellLevel or 1, ctx or {})
        if ok and type(v) == "number" then return math.max(0, v) end
    end

    local base = (cfg.damageBase or 0)
        + math.max(0, (spellLevel or 1) - 1) * (cfg.damagePerLevel or 0)
    local int = getInt(pid)
    local bonusPct = getSpellBonusPct(pid)
    local raw = (base + int * INT_FACTOR)
    return math.max(0, raw * (1.0 + bonusPct))
end

function SpellSystemInit.GetScaledDamage(playerId, spellKey, spellLevel)
    return SpellSystemInit.GetDamageForSpell(playerId, spellKey, spellLevel, nil)
end

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
