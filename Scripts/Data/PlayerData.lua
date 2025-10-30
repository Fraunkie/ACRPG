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
_G.PlayerData = PlayerData  -- Make sure PlayerData is accessible globally
if not PLAYER_DATA then PLAYER_DATA = {} end  -- Ensure PLAYER_DATA is initialized
if not PlayerHero then PlayerHero = {} end  -- Ensure PlayerHero exists

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

            -- basic stats mirror
            stats = { power = 0, defense = 0, speed = 0, crit = 0 },

            -- combat stats mirror
            combat = {
                armor = 0, energyResist = 0, dodge = 0, parry = 0, block = 0,
                critChance = 0, critMult = 1.5,
                spellBonusPct = 0.0, physicalBonusPct = 0.0,
            },

            -- currency
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
    function PlayerData.Get(pid)
        local t = PlayerData[pid]
        if t == nil then
            t = defaultTable()
            PlayerData[pid] = t
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
    function PlayerData.SetHero(pid, unit)
        local pd = PlayerData.Get(pid)
        pd.hero = unit
        PlayerHero[pid] = unit
        return unit
    end
    function PlayerData.GetHero(pid) return PlayerData.Get(pid).hero end

    function PlayerData.SetHeroType(pid, tpe)
        local pd = PlayerData.Get(pid)
        if type(tpe) == "string" and tpe ~= "" then pd.heroType = tpe else pd.heroType = nil end
        return pd.heroType
    end
    function PlayerData.GetHeroType(pid) return PlayerData.Get(pid).heroType end

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

    function PlayerData.SetZone(pid, zone)
        local pd = PlayerData.Get(pid)
        pd.zone = zone or pd.zone
        return pd.zone
    end
    function PlayerData.GetZone(pid) return PlayerData.Get(pid).zone end

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
        if not pd.stats then
            pd.stats = { power = 0, defense = 0, speed = 0, crit = 0 }
        end
        return pd.stats
    end

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
        if tbl and tbl.spellBonusPct     ~= nil then c.spellBonusPct     = tbl.spellBonusPct end
        if tbl and tbl.physicalBonusPct  ~= nil then c.physicalBonusPct  = tbl.physicalBonusPct end
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
