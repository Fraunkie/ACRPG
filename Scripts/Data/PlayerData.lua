if Debug and Debug.beginFile then Debug.beginFile("PlayerData.lua") end
--==================================================
-- PlayerData.lua (MAIN)
-- Single source of truth for per-player runtime state.
--==================================================

if not PlayerData then PlayerData = {} end
_G.PlayerData = PlayerData
PLAYER_DATA = PLAYER_DATA or {}
PlayerHero  = PlayerHero or {}

do
    --------------------------------------------------
    -- Defaults
    --------------------------------------------------
    local function defaultTable()
        return {
            -- identity / session
            hero = nil,
            heroType = nil,
            zone = "YEMMA",
            role = "NONE",
            hasStarted = false,

            -- power/progression mirrors
            powerLevel = 0,
            soulEnergy = 0,
            soulLevel  = 1,
            soulXP     = 0,
            soulNextXP = 200,
            spiritDrive = 0,

            -- read-only basics (from HeroStatSystem)
            stats = { power = 0, defense = 0, speed = 0, crit = 0 },

            -- combat details (mirrored from StatSystem)
            combat = {
                armor = 0,
                energyResist = 0,
                dodge = 0,
                parry = 0,
                block = 0,
                critChance = 0,
                critMult = 1.5,
                spellBonusPct    = 0.0,
                physicalBonusPct = 0.0,
            },

            -- loot / shards
            fragments   = 0,
            ownedShards = {},

            -- UX flags
            lootChatEnabled = true,
            yemmaPromptShown = false,
            yemmaPromptMinimized = false,

            -- intro/meta
            introChoice = nil,
            introCompleted = false,
            introStyle = nil,

            -- tasks / teleports
            hfilTask = { active=false, id=nil, name="", desc="", goalType="", need=0, have=0, rarity="Common" },
            activeTask = nil,
            teleports = {},

            -- optional misc bonuses
            xpBonusPercent = 0,
            statChanceBonusPermil = 0,
            dropLuckBonusPermil = 0,

            --==================================================
            -- Companions & Mercenary (runtime, non-persistent v1)
            --==================================================
            companions = {
                -- List of unlocked companion template ids for the Companion Book.
                -- v1: session-only unless Save/Load later wires it.
                unlocked = {},

                -- Optional current selection id (for UI state); no auto-spawn on load.
                activeId = nil,
            },

            merc = {
                active = false,        -- has an active merc right now
                unit   = nil,          -- unit handle
                role   = "HEALER",     -- v1 only
                mode   = "follow",     -- follow | stay | guard
                band   = "tight",      -- tight | loose
                assist = true,         -- will assist owner (heal/attack)

                -- follow spacing & movement safety
                follow = { min = 200, tight = 350, loose = 600 },
                movement = { chaseLimit = 900, snapDistance = 1800 },

                -- threat routing policy (can be overridden per-spawn/template)
                threatPolicy = {
                    threatMode = "owner",     -- owner | self | split
                    splitToOwner = 1.0,       -- used when threatMode = "split"
                    threatMultSelf = 1.0,     -- multiplier for personal threat
                    threatMultOwner = 1.0,    -- multiplier for routed threat to owner
                    healThreatMult = 1.0,     -- heal-generated threat tuning
                    discardIfOwnerInvalid = true,
                    countForLoot = true,      -- actions always credit owner for loot/rewards
                },

                -- scaling snapshot (derived from owner; recomputed by systems)
                scaling = {
                    useOwner = true,
                    liveRefresh = true,
                    weights = {
                        hpFromSTR       = 22,
                        hpFromINT       = 10,
                        armorFromAGI    = 0.012,
                        healFromINT     = 0.75,
                        healFromSpell   = 0.50,
                        dmgFromSTR      = 0.35,
                        dmgFromAGI      = 0.20,
                    },
                    clamps = {
                        maxHpMult   = 3.0,
                        maxHealMult = 2.5,
                        maxDmgMult  = 1.5,
                    },
                    snapshot = { hp = 0, armor = 0, healSmall = 0, healBig = 0, atk = 0 },
                },

                -- lightweight runtime cache for movement/ai
                blackboard = {
                    target   = nil,
                    lastX    = 0.0,
                    lastY    = 0.0,
                    failedPaths = 0,
                    nextTick = 0.0,
                },
            },

            --==================================================
            -- Control + Camera State (Direct Control / WoW-like camera)
            --==================================================
            control = {
                -- modes
                direct   = false,  -- WASD + camera enabled
                uiFocus  = false,  -- suspend input when UI open

                -- mouse buttons
                rmb      = false,
                lmb      = false,

                -- camera rig (core)
                yaw      = 0.0,
                pitch    = 308.0,
                dist     = 1950.0,
                distMin  = 1500.0,
                distMax  = 2600.0,
                shoulder = 120.0,
                height   = 250.0,

                -- feel
                lead     = 0.20,
                ease     = 0.15,

                -- behavior
                strafeMode = false,
                profile    = "WASD",

                -- occlusion & cliff-aware tuning
                forwardVisible  = 700.0,
                maxLift         = 120.0,
                yawPeek         = 10.0,
                restoreEase     = 0.25,
                cliffPitchBoost = 8.0,

                -- targeting (Tab lock)
                target        = nil,   -- unit handle or nil
                isLocked      = false,
                targetFx      = nil,   -- effect handle or nil (client-side)
                lockFov       = 60.0,  -- degrees (was 35)
                lockRange     = 4000.0, -- << long-range targeting (was 900)
                lockCycleCD   = 0.15,  -- min time between cycles
                lockClearDTap = 0.30,  -- double-tap window to clear
            },
        }
    end

    --------------------------------------------------
    -- Accessors
    --------------------------------------------------
    function PlayerData.Get(pid)
        local t = PLAYER_DATA[pid]
        if t == nil then
            t = defaultTable()
            PLAYER_DATA[pid] = t
        end
        return t
    end

    function PlayerData.GetField(pid, key, defaultValue)
        local t = PlayerData.Get(pid)
        local v = t[key]
        if v == nil then return defaultValue end
        return v
    end

    --------------------------------------------------
    -- Companion Book (unlocked list)
    --------------------------------------------------
    function PlayerData.GetCompanions(pid)
        local pd = PlayerData.Get(pid)
        pd.companions = pd.companions or { unlocked = {}, activeId = nil }
        pd.companions.unlocked = pd.companions.unlocked or {}
        return pd.companions
    end

    function PlayerData.UnlockCompanion(pid, templateId)
        if not templateId or templateId == "" then return false end
        local comp = PlayerData.GetCompanions(pid)
        local list = comp.unlocked
        -- prevent duplicates
        for i = 1, #list do
            if list[i] == templateId then return false end
        end
        list[#list+1] = templateId
        return true
    end

    function PlayerData.HasCompanionUnlocked(pid, templateId)
        local comp = PlayerData.GetCompanions(pid)
        local list = comp.unlocked
        for i = 1, #list do
            if list[i] == templateId then return true end
        end
        return false
    end

    function PlayerData.ListCompanions(pid)
        local comp = PlayerData.GetCompanions(pid)
        local list = comp.unlocked
        local out = {}
        for i = 1, #list do out[i] = list[i] end
        return out
    end

    function PlayerData.SetActiveCompanionId(pid, templateId)
        local comp = PlayerData.GetCompanions(pid)
        if templateId == nil or templateId == "" then
            comp.activeId = nil
            return nil
        end
        -- allow setting even if not unlocked in DevMode elsewhere; here we just assign
        comp.activeId = templateId
        return comp.activeId
    end

    function PlayerData.GetActiveCompanionId(pid)
        return PlayerData.GetCompanions(pid).activeId
    end

    --------------------------------------------------
    -- Merc (runtime)
    --------------------------------------------------
    function PlayerData.GetMerc(pid)
        local pd = PlayerData.Get(pid)
        pd.merc = pd.merc or {
            active=false, unit=nil, role="HEALER", mode="follow", band="tight", assist=true,
            follow={ min=200, tight=350, loose=600 }, movement={ chaseLimit=900, snapDistance=1800 },
            threatPolicy={ threatMode="owner", splitToOwner=1.0, threatMultSelf=1.0, threatMultOwner=1.0, healThreatMult=1.0, discardIfOwnerInvalid=true, countForLoot=true },
            scaling={ useOwner=true, liveRefresh=true, weights={ hpFromSTR=22, hpFromINT=10, armorFromAGI=0.012, healFromINT=0.75, healFromSpell=0.50, dmgFromSTR=0.35, dmgFromAGI=0.20 },
                      clamps={ maxHpMult=3.0, maxHealMult=2.5, maxDmgMult=1.5 }, snapshot={ hp=0, armor=0, healSmall=0, healBig=0, atk=0 } },
            blackboard={ target=nil, lastX=0.0, lastY=0.0, failedPaths=0, nextTick=0.0 },
        }
        return pd.merc
    end

    function PlayerData.HasMerc(pid)
        local m = PlayerData.GetMerc(pid)
        return (m.active == true and m.unit ~= nil) and true or false
    end

    function PlayerData.SetMercField(pid, key, value)
        local m = PlayerData.GetMerc(pid)
        m[key] = value
        return m[key]
    end

    function PlayerData.ClearMerc(pid)
        local m = PlayerData.GetMerc(pid)
        m.active = false
        m.unit   = nil
        m.role   = m.role or "HEALER"
        m.mode   = "follow"
        m.band   = "tight"
        m.assist = true
        m.blackboard = { target=nil, lastX=0.0, lastY=0.0, failedPaths=0, nextTick=0.0 }
        return true
    end

    --------------------------------------------------
    -- Control accessors
    --------------------------------------------------
    function PlayerData.GetControl(pid)
        local pd = PlayerData.Get(pid)
        pd.control = pd.control or {}
        return pd.control
    end

    function PlayerData.SetControlField(pid, key, value)
        local c = PlayerData.GetControl(pid)
        c[key] = value
        return c[key]
    end

    function PlayerData.SetDirectControl(pid, enabled)
        local c = PlayerData.GetControl(pid)
        c.direct = enabled and true or false
        return c.direct
    end

    function PlayerData.IsDirectControl(pid)
        return PlayerData.GetControl(pid).direct and true or false
    end

    function PlayerData.SetUIFocus(pid, enabled)
        local c = PlayerData.GetControl(pid)
        c.uiFocus = enabled and true or false
        return c.uiFocus
    end

    function PlayerData.IsUIFocus(pid)
        return PlayerData.GetControl(pid).uiFocus and true or false
    end

    function PlayerData.SetMouseButtons(pid, leftDown, rightDown)
        local c = PlayerData.GetControl(pid)
        if leftDown ~= nil then c.lmb = leftDown and true or false end
        if rightDown ~= nil then c.rmb = rightDown and true or false end
        return c.lmb, c.rmb
    end

    --------------------------------------------------
    -- Hero binding
    --------------------------------------------------
    function PlayerData.SetHero(pid, unit)
        local pd = PlayerData.Get(pid)
        pd.hero = unit
        PlayerHero[pid] = unit
        return unit
    end

    function PlayerData.GetHero(pid)
        return PlayerData.Get(pid).hero
    end

    -- hero type helpers
    function PlayerData.SetHeroType(pid, tpe)
        local pd = PlayerData.Get(pid)
        if type(tpe) == "string" and tpe ~= "" then
            pd.heroType = tpe
        else
            pd.heroType = nil
        end
        return pd.heroType
    end
    function PlayerData.GetHeroType(pid)
        return PlayerData.Get(pid).heroType
    end

    --------------------------------------------------
    -- Power mirrors
    --------------------------------------------------
    function PlayerData.RefreshPower(pid)
        local pd = PlayerData.Get(pid)
        local str = (rawget(_G, "PlayerMStr") and PlayerMStr[pid]) or 0
        local agi = (rawget(_G, "PlayerMAgi") and PlayerMAgi[pid]) or 0
        local int = (rawget(_G, "PlayerMInt") and PlayerMInt[pid]) or 0
        pd.powerLevel = math.max(0, math.floor((str + agi + int) / 3))
        return pd.powerLevel
    end
    function PlayerData.GetPowerLevel(pid) return (PlayerData.Get(pid).powerLevel or 0) end
    function PlayerData.GetSoulEnergy(pid) return (PlayerData.Get(pid).soulEnergy or 0) end

    --------------------------------------------------
    -- Souls / fragments
    --------------------------------------------------
    function PlayerData.AddSoul(pid, amount)
        local pd = PlayerData.Get(pid)
        pd.soulEnergy = math.max(0, (pd.soulEnergy or 0) + (amount or 0))
        return pd.soulEnergy
    end
    function PlayerData.AddFragments(pid, amount)
        local pd = PlayerData.Get(pid)
        pd.fragments = math.max(0, (pd.fragments or 0) + (amount or 0))
        return pd.fragments
    end

    --------------------------------------------------
    -- Zone helpers
    --------------------------------------------------
    function PlayerData.SetZone(pid, zone)
        local pd = PlayerData.Get(pid)
        pd.zone = zone or pd.zone
        return pd.zone
    end
    function PlayerData.GetZone(pid)
        return PlayerData.Get(pid).zone
    end

    --------------------------------------------------
    -- Basic stats mirror
    --------------------------------------------------
    function PlayerData.SetStats(pid, tbl)
        local pd = PlayerData.Get(pid)
        local s = pd.stats or {}
        s.power   = (tbl and tbl.power)   or s.power   or 0
        s.defense = (tbl and tbl.defense) or s.defense or 0
        s.speed   = (tbl and tbl.speed)   or s.speed   or 0
        s.crit    = (tbl and tbl.crit)    or s.crit    or 0
        pd.stats = s
        return s
    end

    function PlayerData.GetStats(pid)
        local pd = PlayerData.Get(pid)
        local s = pd.stats
        if not s then
            s = { power = 0, defense = 0, speed = 0, crit = 0 }
            pd.stats = s
        end
        return s
    end

    --------------------------------------------------
    -- Combat stats mirror
    --------------------------------------------------
    function PlayerData.SetCombat(pid, tbl)
        local pd = PlayerData.Get(pid)
        local c = pd.combat or {}
        c.armor        = (tbl and tbl.armor)        or c.armor        or 0
        c.energyResist = (tbl and tbl.energyResist) or c.energyResist or 0
        c.dodge        = (tbl and tbl.dodge)        or c.dodge        or 0
        c.parry        = (tbl and tbl.parry)        or c.parry        or 0
        c.block        = (tbl and tbl.block)        or c.block        or 0
        c.critChance   = (tbl and tbl.critChance)   or c.critChance   or 0
        c.critMult     = (tbl and tbl.critMult)     or c.critMult     or 1.5

        if tbl and tbl.spellBonusPct ~= nil then c.spellBonusPct = tbl.spellBonusPct end
        if tbl and tbl.physicalBonusPct ~= nil then c.physicalBonusPct = tbl.physicalBonusPct end

        pd.combat = c
        return c
    end

    function PlayerData.GetCombat(pid)
        local pd = PlayerData.Get(pid)
        if not pd.combat then
            pd.combat = {
                armor = 0, energyResist = 0, dodge = 0, parry = 0, block = 0,
                critChance = 0, critMult = 1.5,
                spellBonusPct = 0.0, physicalBonusPct = 0.0
            }
        end
        return pd.combat
    end

    --------------------------------------------------
    -- Convenience getters
    --------------------------------------------------
    function PlayerData.GetArmor(pid)        return PlayerData.GetCombat(pid).armor end
    function PlayerData.GetEnergyResist(pid) return PlayerData.GetCombat(pid).energyResist end
    function PlayerData.GetDodge(pid)        return PlayerData.GetCombat(pid).dodge end
    function PlayerData.GetParry(pid)        return PlayerData.GetCombat(pid).parry end
    function PlayerData.GetBlock(pid)        return PlayerData.GetCombat(pid).block end
    function PlayerData.GetCritChance(pid)   return PlayerData.GetCombat(pid).critChance end
    function PlayerData.GetCritMult(pid)     return PlayerData.GetCombat(pid).critMult end

    function PlayerData.GetSpellBonusPct(pid)    return PlayerData.GetCombat(pid).spellBonusPct or 0.0 end
    function PlayerData.GetPhysicalBonusPct(pid) return PlayerData.GetCombat(pid).physicalBonusPct or 0.0 end
    function PlayerData.SetSpellBonusPct(pid, pct)
        local c = PlayerData.GetCombat(pid)
        c.spellBonusPct = pct or 0.0
        return c.spellBonusPct
    end
    function PlayerData.SetPhysicalBonusPct(pid, pct)
        local c = PlayerData.GetCombat(pid)
        c.physicalBonusPct = pct or 0.0
        return c.physicalBonusPct
    end
    function PlayerData.AddSpellBonusPct(pid, delta)
        local c = PlayerData.GetCombat(pid)
        c.spellBonusPct = (c.spellBonusPct or 0.0) + (delta or 0.0)
        return c.spellBonusPct
    end
    function PlayerData.AddPhysicalBonusPct(pid, delta)
        local c = PlayerData.GetCombat(pid)
        c.physicalBonusPct = (c.physicalBonusPct or 0.0) + (delta or 0.0)
        return c.physicalBonusPct
    end

    --------------------------------------------------
    -- Init / events
    --------------------------------------------------
    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                PLAYER_DATA[pid] = PLAYER_DATA[pid] or defaultTable()
            end
        end

        local function _PD_OnHeroStatsChanged(e)
            if not e or not e.unit then return end
            local p = GetPlayerId(GetOwningPlayer(e.unit))
            if p == nil then return end
            if _G.HeroStatSystem and HeroStatSystem.GetAll then
                local all = HeroStatSystem.GetAll(e.unit)
                PlayerData.SetStats(p, {
                    power   = (all and all.power)   or 0,
                    defense = (all and all.defense) or 0,
                    speed   = (all and all.speed)   or 0,
                    crit    = (all and all.crit)    or 0,
                })
            end
            -- optional hint for systems that want to live-refresh merc scaling
            local m = PlayerData.GetMerc(p)
            if m and m.scaling and m.scaling.liveRefresh then
                -- a system can listen for this ProcBus event to recompute scaling
                if rawget(_G, "ProcBus") and ProcBus.Emit then
                    ProcBus.Emit("PlayerMercNeedsRefresh", { pid = p })
                end
            end
        end

        local function _PD_OnCombatStatsChanged(e)
            if not e then return end
            local u = e.unit
            if not u then return end
            local p = GetPlayerId(GetOwningPlayer(u)); if p == nil then return end

            local src = e.combat
            if not src and _G.StatSystem and StatSystem.GetCombat then
                src = StatSystem.GetCombat(u)
            end

            if src then
                PlayerData.SetCombat(p, src)
            end

            -- same refresh hint on combat changes
            local m = PlayerData.GetMerc(p)
            if m and m.scaling and m.scaling.liveRefresh then
                if rawget(_G, "ProcBus") and ProcBus.Emit then
                    ProcBus.Emit("PlayerMercNeedsRefresh", { pid = p })
                end
            end
        end

        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("HeroStatsChanged", _PD_OnHeroStatsChanged)
            PB.On("CombatStatsChanged", _PD_OnCombatStatsChanged)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("PlayerData")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
