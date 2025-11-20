if Debug and Debug.beginFile then Debug.beginFile("PlayerData.lua") end
--==================================================
-- PlayerData.lua (v1.3 WC3-safe)
-- Single source of truth for per-player runtime state.
-- • Companion book + unlocks
-- • Camera/control fields for WoW-style mouse look
-- • Minimal stat mirrors
-- • No percent symbols anywhere
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
            soulLevel  = 1,
            powerLevel = 0,
            soulXP     = 0,
            soulNextXP = 200,
            spiritDrive = 0,
            talentpoints = 0,
            spellpoints = 1,
            spellranks = {
                passives = {

                },
                actives = {

                },
            },
            talentranks = {},
            knownspells = {
                passives ={
                    phantomEcho = false, soulStrike = false,},
                actives = {

                }
            },

            -- basic stats mirror
            stats = {
                powerLevel = 0,
                power = 0,
                defense = 0,
                speed = 0,
                crit = 0,
                basestr = 10, -- base strength
                baseagi = 10, -- base agility
                baseint = 10, -- base intelligence
                strmulti = 1.0,
                agimulti = 1.0,
                intmulti = 1.0,
            },

            -- combat stats mirror
            combat = {
                armor = 0, damage = 0, energyDamage = 0, energyResist = 0.0, dodge = 0.0, parry = 0.0, block = 0.0,
                critChance = 0.0, critMult = 150.0,
                spellBonusPct = 0.0, physicalBonusPct = 0.0,
            },

            -- currency
            ownedShards             = {},

            currency = {
            capsuleCoins            = 0,
            oldZeni                 = 0,
            },

            -- per-fragment-type currency (dummy pickup items)
            fragmentsByKind = {
                db     = 0,   -- Dragon Ball Fragment (I00U)
                digi   = 0,   -- Digi Fragment (I012)
                poke   = 0,   -- Poké Fragment (I00Z)
                chakra = 0,   -- Chakra Fragment (I00Y)
            },

            resources = { 
                mining                  = { dragonstoneore = 0, chakracrystals = 0, digimetal = 0, mysticslate = 0, saiyancorefragments = 0, electrosand = 0,
                                            biometal = 0, soulstoneshards = 0, vortexgemstone = 0, neonite = 0, },
                woodcutting             = {digilog = 0, chakrawood = 0, kiroot = 0,soulbark = 0, firevine = 0, elderleaf = 0, shinobibranch = 0, mimicsprout = 0,
                                            digitalsap = 0, sacredbranch = 0, },
                herblore                = {healingfruits = 0, mysticfern = 0, spiritbloom = 0, chakraherb = 0, digiflareleaf = 0, rebirthvine = 0, soulflower = 0,
                                            phoenixpetal = 0, vitalroot = 0, etherblossom = 0,},
                fishing                 = {spiritfish = 0, digishimmerfish = 0, chakraeel = 0, dragonfin = 0, rebirthjellyfish = 0, crystalcarp = 0, digimantaray = 0,
                                            saiyanseaserpent = 0, healingstarfish = 0, oceanicbubbles = 0,},
                
            },

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
            xpBonusPercent = 0.00,
            statChanceBonusPermil = 0,
            dropLuckBonusPermil = 0,

            --------------------------------------------------
            -- Companions
            --------------------------------------------------
            companions = {
                unlocked = {},   -- unlocked template ids
                activeId = nil,  -- UI selection only
            },

            --------------------------------------------------
            -- Control and Camera (for DirectControlMotor)
            --------------------------------------------------
            control = {
                -- mode
                direct = false,   -- WASD camera mode
                uiFocus = false,  -- pause input when UI open

                -- mouse state
                lmb = false,
                rmb = false,

                -- camera rig
                yaw      = 0.0,   -- absolute camera yaw around hero
                pitch    = 352.0, -- keep locked unless you add vertical look
                dist     = 460.0, -- follow distance
                shoulder = 120.0, -- horizontal shoulder offset
                height   = 140.0, -- camera z offset

                -- free look helpers (LMB drag)
                freeLookYaw  = 0.0,  -- accumulated yaw delta while dragging
                lastFreeLook = 0.0,  -- os.clock of last release
                wantRecenter = false,-- request smooth snap behind hero

                -- behavior toggles
                strafeMode = false,  -- RMB strafe vs face-turn
                profile    = "WASD",

                -- targeting hint from your lock system
                target        = nil,
                isLocked      = false,
                lockFov       = 60.0,
                lockRange     = 4000.0,
                lockCycleCD   = 0.15,
                lockClearDTap = 0.30,
            },
        }
    end

    --------------------------------------------------
    -- Accessors
    --------------------------------------------------
---@diagnostic disable-next-line: duplicate-set-field
    function PlayerData.Get(pid)
        local t = PLAYER_DATA[pid]
        if t == nil then
            t = defaultTable()
            PLAYER_DATA[pid] = t
        end
        return t
    end

---@diagnostic disable-next-line: duplicate-set-field
    function PlayerData.GetField(pid, key, defaultValue)
        local t = PlayerData.Get(pid)
        local v = t[key]
        if v == nil then return defaultValue end
        return v
    end
    --------------------------------------------------
    -- Companions (validates against CompanionCatalog)
    --------------------------------------------------
    function PlayerData.GetCompanions(pid)
        local pd = PlayerData.Get(pid)
        pd.companions = pd.companions or { unlocked = {}, activeId = nil }
        pd.companions.unlocked = pd.companions.unlocked or {}
        return pd.companions
    end

    function PlayerData.UnlockCompanion(pid, templateId)
        if type(templateId) ~= "string" or templateId == "" then return false end
        local CC = rawget(_G, "CompanionCatalog")
        if not (CC and CC.Get and CC.Get(templateId)) then
            print("[PlayerData] UnlockCompanion ignored, invalid id: " .. tostring(templateId))
            return false
        end
        local comp = PlayerData.GetCompanions(pid)
        for i = 1, #comp.unlocked do
            if comp.unlocked[i] == templateId then return false end
        end
        comp.unlocked[#comp.unlocked + 1] = templateId
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit("CompanionUnlocked", { pid = pid, id = templateId }) end
        return true
    end

    function PlayerData.HasCompanionUnlocked(pid, templateId)
        local comp = PlayerData.GetCompanions(pid)
        for i = 1, #comp.unlocked do
            if comp.unlocked[i] == templateId then return true end
        end
        return false
    end

    function PlayerData.ListCompanions(pid)
        local comp = PlayerData.GetCompanions(pid)
        local out = {}
        for i = 1, #comp.unlocked do out[i] = comp.unlocked[i] end
        return out
    end

    function PlayerData.SetActiveCompanionId(pid, templateId)
        local comp = PlayerData.GetCompanions(pid)
        local CC = rawget(_G, "CompanionCatalog")
        if not (CC and CC.Get and CC.Get(templateId)) then
            templateId = nil
        end
        comp.activeId = templateId
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit("CompanionActiveChanged", { pid = pid, id = comp.activeId }) end
        return comp.activeId
    end

    function PlayerData.ClearActiveCompanion(pid)
        return PlayerData.SetActiveCompanionId(pid, nil)
    end

    function PlayerData.GetActiveCompanionId(pid)
        return PlayerData.GetCompanions(pid).activeId
    end

    function PlayerData.ListCompanionsResolved(pid)
        local ids = PlayerData.ListCompanions(pid)
        local CC  = rawget(_G, "CompanionCatalog")
        local out = {}
        for i = 1, #ids do
            local id = ids[i]
            local d  = (CC and CC.Get) and CC.Get(id) or nil
            out[i] = {
                id   = id,
                name = d and d.name or id,
                role = d and d.role or "",
                icon = d and d.icon or nil,
                desc = d and d.desc or "",
            }
        end
        return out
    end

    --------------------------------------------------
    -- Hero / Stats
    --------------------------------------------------
    
    function PlayerData.GetCurrency(pid, currencyType)
        local pd = PlayerData.Get(pid)
        -- Check if the currency type exists
        if pd.currency and pd.currency[currencyType] then
            return pd.currency[currencyType]
        end
        return nil  -- Return nil if the currency type doesn't exist
    end

    function PlayerData.AddCurrency(pid, currencyType, amount)
        local pd = PlayerData.Get(pid)
        -- Check if the currency type exists
        if pd.currency and pd.currency[currencyType] then
            pd.currency[currencyType] = math.max(0, (pd.currency[currencyType] or 0) + (amount or 0))  -- Add and prevent negative values
            return pd.currency[currencyType]
        end
        return nil  -- Return nil if the currency type doesn't exist
    end

    function PlayerData.GetResource(pid, category, resource)
        local pd = PlayerData.Get(pid)
        -- Check if category and resource exist
        if pd.resources and pd.resources[category] and pd.resources[category][resource] ~= nil then
            return pd.resources[category][resource]
        end
        return nil  -- Return nil if the resource doesn't exist
    end

    function PlayerData.SetResource(pid, category, resource, amount)
        local pd = PlayerData.Get(pid)
        -- Check if category exists
        if pd.resources and pd.resources[category] then
            -- Check if the resource exists within the category
            if pd.resources[category][resource] ~= nil then
                pd.resources[category][resource] = amount  -- Update the resource value
                return pd.resources[category][resource]
            end
        end
        return nil  -- Return nil if the resource/category doesn't exist
    end

    function PlayerData.SetHero(pid, unit)
        local pd = PlayerData.Get(pid)
        pd.hero = unit
        PlayerHero[pid] = unit
        return unit
    end

    function PlayerData.GetHero(pid)
        return PlayerData.Get(pid).hero
    end

    function PlayerData.SetHeroType(pid, tpe)
        local pd = PlayerData.Get(pid)
        if type(tpe) == "string" and tpe ~= "" then pd.heroType = tpe else pd.heroType = nil end
        return pd.heroType
    end

    function PlayerData.GetHeroType(pid)
        return PlayerData.Get(pid).heroType
    end

    function PlayerData.RefreshPower(pid)
        local pd = PlayerData.Get(pid)
        local str = (pd.stats.basestr or 0) * (pd.stats.strmulti or 1.0)
        local agi = (pd.stats.baseagi or 0) * (pd.stats.agimulti or 1.0)
        local int = (pd.stats.baseint or 0) * (pd.stats.intmulti or 1.0)
        pd.powerLevel = math.max(0, math.floor(str + agi + int))
        return pd.powerLevel
    end

    function PlayerData.GetPowerLevel(pid)
        return (PlayerData.Get(pid).powerLevel or 0)
    end

    function PlayerData.GetEnergyDamage(pid, hero, base, multi)
        local pd = PlayerData.Get(pid)  -- Get player data
        local int = GetHeroInt(hero, true)  -- Get hero's intelligence
        local spb = pd.stats.spellBonusPct  -- Get the player's spell bonus percentage
        local energyDamage = base + (int * multi)
            energyDamage = energyDamage * (1.00 + spb)


        return energyDamage
    end 

    function PlayerData.GetSoulEnergy(pid)
        return (PlayerData.Get(pid).soulXP or 0)
    end

    function PlayerData.GetSoulLevel(pid)
        return (PlayerData.Get(pid).soulLevel or 0)
    end

    function PlayerData.AddSoul(pid, amount)
        local pd = PlayerData.Get(pid)
        pd.soulXP = math.max(0, (pd.soulXP or 0) + (amount or 0))
        return pd.soulXP
    end

    function PlayerData.AddFragments(pid, amount)
        local pd = PlayerData.Get(pid)
        pd.fragments = math.max(0, (pd.fragments or 0) + (amount or 0))
        return pd.fragments
    end

    function PlayerData.SetZone(pid, zone)
        local pd = PlayerData.Get(pid)
        pd.zone = zone or pd.zone
        return pd.zone
    end

    function PlayerData.GetZone(pid)
        return PlayerData.Get(pid).zone
    end

    function PlayerData.SetStats(pid, tbl)
        local pd = PlayerData.Get(pid)
        local s = pd.stats or {}
        s.power                         = (tbl and tbl.power)           or s.power          or 0
        s.defense                       = (tbl and tbl.defense)         or s.defense        or 0
        s.damage                        = (tbl and tbl.damage)          or s.damage        or 0
        s.speed                         = (tbl and tbl.speed)           or s.speed          or 0
        s.basestr                       = (tbl and tbl.basestr)         or s.basestr        or 0
        s.baseagi                       = (tbl and tbl.baseagi)         or s.baseagi        or 0
        s.baseint                       = (tbl and tbl.baseint)         or s.baseint        or 0
        s.strmulti                      = (tbl and tbl.strmulti)        or s.strmulti        or 0.0
        s.agimulti                      = (tbl and tbl.agimulti)        or s.agimulti        or 0.0
        s.intmulti                      = (tbl and tbl.intmulti)        or s.intmulti        or 0.0
        pd.stats = s
        return s
    end

    function PlayerData.GetStats(pid)
        local pd = PlayerData.Get(pid)
        if not pd.stats then
            pd.stats = {
                power = 0, defense = 0, speed = 0, damage = 0,
                basestr = 0, baseagi = 0, baseint = 0,
                strmulti = 1.0, agimulti = 1.0, intmulti = 1.0,
            }
        end
        return pd.stats
    end

    function PlayerData.SetCombat(pid, tbl)
        local pd = PlayerData.Get(pid)
        local c = pd.combat or {}
        c.armor        = (tbl and tbl.armor)        or c.armor        or 0
        c.damage       =(tbl and tbl.damage)        or c.damage       or 0
        c.energyDamage =(tbl and tbl.energyDamage)  or c.energyDamage or 0
        c.energyResist = (tbl and tbl.energyResist) or c.energyResist or 0.0
        c.dodge        = (tbl and tbl.dodge)        or c.dodge        or 0.0
        c.parry        = (tbl and tbl.parry)        or c.parry        or 0.0
        c.block        = (tbl and tbl.block)        or c.block        or 0.0
        c.critChance   = (tbl and tbl.critChance)   or c.critChance   or 0.0
        c.critMult     = (tbl and tbl.critMult)     or c.critMult     or 150.0
        if tbl and tbl.spellBonusPct     ~= nil then c.spellBonusPct     = tbl.spellBonusPct end
        if tbl and tbl.physicalBonusPct  ~= nil then c.physicalBonusPct  = tbl.physicalBonusPct end
        pd.combat = c
        return c
    end

    function PlayerData.GetCombat(pid)
        local pd = PlayerData.Get(pid)
        if not pd.combat then
            pd.combat = {
                armor = 0, damage = 0, energyDamage = 0, energyResist = 0.0, dodge = 0.0, parry = 0.0, block = 0.0,
                critChance = 0.0, critMult = 150.0,
                spellBonusPct = 0.0, physicalBonusPct = 0.0,
            }
        end
        return pd.combat
    end

    --------------------------------------------------
    -- Control / Camera helpers
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
        if leftDown  ~= nil then c.lmb = leftDown  and true or false end
        if rightDown ~= nil then c.rmb = rightDown and true or false end
        return c.lmb, c.rmb
    end

    -- Free look helpers used by the camera system
    function PlayerData.SetFreeLookYaw(pid, yawDelta)
        local c = PlayerData.GetControl(pid)
        c.freeLookYaw = yawDelta or 0.0
        return c.freeLookYaw
    end

    function PlayerData.MarkFreeLookReleased(pid, clockNow)
        local c = PlayerData.GetControl(pid)
        c.lastFreeLook = clockNow or 0.0
        return c.lastFreeLook
    end

    function PlayerData.RequestCameraRecenter(pid, flag)
        local c = PlayerData.GetControl(pid)
        c.wantRecenter = flag and true or false
        return c.wantRecenter
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                PLAYER_DATA[pid] = PLAYER_DATA[pid] or defaultTable()
            end
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("PlayerData")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
