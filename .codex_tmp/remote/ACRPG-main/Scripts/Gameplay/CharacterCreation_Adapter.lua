if Debug and Debug.beginFile then Debug.beginFile("CharacterCreation_Adapter.lua") end
--==================================================
-- CharacterCreation_Adapter.lua
-- • Bridge between CharacterCreation and Save/Load system
-- • Handles future save slot loading, new soul creation, and persistence
-- • Currently stubs out with dev-safe placeholders
--==================================================

if not CharacterCreation_Adapter then CharacterCreation_Adapter = {} end
_G.CharacterCreation_Adapter = CharacterCreation_Adapter

do
    local SAVE_DIR = "AnimecraftSaves" -- placeholder folder for future save integration

    --------------------------------------------------
    -- Internal references
    --------------------------------------------------
    local function PD(pid)
        PLAYER_DATA = PLAYER_DATA or {}
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end

    --------------------------------------------------
    -- Future: Load Save Slot
    --------------------------------------------------
    function CharacterCreation_Adapter.LoadSoul(pid, slotName)
        local p = Player(pid)
        DisplayTextToPlayer(p, 0, 0, "Attempting to load soul slot: " .. tostring(slotName))

        -- Prefer an external save system when present
        if SaveLoadSystem and SaveLoadSystem.Load then
            local ok, err = pcall(SaveLoadSystem.Load, pid, slotName)
            if ok then return end
            if err then
                DisplayTextToPlayer(p, 0, 0, "SaveLoadSystem error; falling back: " .. tostring(err))
            end
        end

        -- Minimal in-memory fallback: reconstruct hero from a cached snapshot if available
        CharacterCreation_Adapter.__MEM_SAVES = CharacterCreation_Adapter.__MEM_SAVES or {}
        local mem = CharacterCreation_Adapter.__MEM_SAVES
        local slot = slotName or "slot1"
        local snap = mem[pid] and mem[pid][slot] or nil

        local function readSpawnXY()
            if GameBalance then
                if GameBalance.SPAWN then
                    return GameBalance.SPAWN.x or 0, GameBalance.SPAWN.y or 0
                end
                if GameBalance.HUB_COORDS and GameBalance.HUB_COORDS.SPAWN then
                    return GameBalance.HUB_COORDS.SPAWN.x or 0, GameBalance.HUB_COORDS.SPAWN.y or 0
                end
            end
            return 0, 0
        end

        if snap then
            local pd = PD(pid)
            local spawnX, spawnY = readSpawnXY()
            local unitId = snap.heroType or FourCC("H001")
            local hero = CreateUnit(p, unitId, spawnX, spawnY, 270.0)
            pd.hero = hero
            if _G.PlayerHero then PlayerHero[pid] = hero end

            pd.soulEnergy = snap.soulEnergy or pd.soulEnergy
            pd.soulLevel  = snap.soulLevel  or pd.soulLevel
            pd.soulXP     = snap.soulXP     or pd.soulXP
            pd.zone       = snap.zone       or pd.zone

            -- Restore hero stats (base first, then recalc)
            local baseStr = snap.baseStr or (PlayerBaseStr and PlayerBaseStr[pid]) or 2
            local baseAgi = snap.baseAgi or (PlayerBaseAgi and PlayerBaseAgi[pid]) or 2
            local baseInt = snap.baseInt or (PlayerBaseInt and PlayerBaseInt[pid]) or 2

            if HeroStatSystem and HeroStatSystem.InitializeHeroStats and HeroStatSystem.SetPlayerBaseStat then
                pcall(HeroStatSystem.InitializeHeroStats, pid)
                pcall(HeroStatSystem.SetPlayerBaseStat, pid, "str", baseStr)
                pcall(HeroStatSystem.SetPlayerBaseStat, pid, "agi", baseAgi)
                pcall(HeroStatSystem.SetPlayerBaseStat, pid, "int", baseInt)
            else
                -- Fallback: set attributes directly if system not present
                SetHeroStr(hero, snap.mStr or baseStr, true)
                SetHeroAgi(hero, snap.mAgi or baseAgi, true)
                SetHeroInt(hero, snap.mInt or baseInt, true)
                if _G.PlayerMStr then PlayerMStr[pid] = GetHeroStr(hero, true) end
                if _G.PlayerMAgi then PlayerMAgi[pid] = GetHeroAgi(hero, true) end
                if _G.PlayerMInt then PlayerMInt[pid] = GetHeroInt(hero, true) end
            end

            if snap.powerLevel then
                pd.powerLevel = snap.powerLevel
            end

            -- EXTEND LOAD: apply additional saved fields to PlayerData here
            -- Example:
            -- pd.fragments = snap.fragments or pd.fragments

            DisplayTextToPlayer(p, 0, 0, "Loaded soul from memory snapshot.")
            if GetLocalPlayer() == p then
                PanCameraToTimed(spawnX, spawnY, 0.30)
                ClearSelection()
                SelectUnit(hero, true)
            end
            return
        end

        -- Fallback to creating a fresh soul
        DisplayTextToPlayer(p, 0, 0, "No save detected; creating placeholder soul.")
        if CharacterCreation and CharacterCreation.Begin then
            pcall(CharacterCreation.Begin, pid)
        end
    end

    --------------------------------------------------
    -- Future: Save Soul Slot
    --------------------------------------------------
    function CharacterCreation_Adapter.SaveSoul(pid, slotName)
        local p = Player(pid)
        local pd = PD(pid)
        DisplayTextToPlayer(p, 0, 0, "Saving soul data for " .. GetPlayerName(p) .. "...")

        -- TODO: implement real save serialization
        if SaveLoadSystem and SaveLoadSystem.Save then
            -- Try with slot support first; fallback to legacy signature
            local ok = pcall(SaveLoadSystem.Save, pid, pd, slotName)
            if not ok then
                pcall(SaveLoadSystem.Save, pid, pd)
            end
        else
            -- Lightweight in-memory snapshot for fast testing
            CharacterCreation_Adapter.__MEM_SAVES = CharacterCreation_Adapter.__MEM_SAVES or {}
            local mem = CharacterCreation_Adapter.__MEM_SAVES
            mem[pid] = mem[pid] or {}
            local slot = slotName or "slot1"

            local heroType
            if pd.hero and GetUnitTypeId(pd.hero) ~= 0 then
                heroType = GetUnitTypeId(pd.hero)
            end

            mem[pid][slot] = {
                heroType   = heroType,
                soulEnergy = pd.soulEnergy or 0,
                soulLevel  = pd.soulLevel or 1,
                soulXP     = pd.soulXP or 0,
                zone       = pd.zone or "YEMMA",
                -- Stats snapshot (basics only)
                baseStr    = (PlayerBaseStr and PlayerBaseStr[pid]) or 2,
                baseAgi    = (PlayerBaseAgi and PlayerBaseAgi[pid]) or 2,
                baseInt    = (PlayerBaseInt and PlayerBaseInt[pid]) or 2,
                mStr       = (_G.PlayerMStr and PlayerMStr[pid]) or nil,
                mAgi       = (_G.PlayerMAgi and PlayerMAgi[pid]) or nil,
                mInt       = (_G.PlayerMInt and PlayerMInt[pid]) or nil,
                powerLevel = pd.powerLevel or nil,
                -- EXTEND SAVE: add more PlayerData fields here
                -- Example:
                -- fragments = pd.fragments,
            }
            DisplayTextToPlayer(p, 0, 0, "Saved to memory snapshot (" .. slot .. ").")
        end
    end

    --------------------------------------------------
    -- Hook from CharacterCreation Menu
    --------------------------------------------------
    function CharacterCreation_Adapter.Start(pid, onDone)
        -- Simple entry used by boot flow: attempt load, otherwise create new
        CharacterCreation_Adapter.LoadSoul(pid, "slot1")
        if type(onDone) == "function" then
            pcall(onDone)
        end
    end

    function CharacterCreation_Adapter.OnMenuChoice(pid, choice)
        -- choice can be: "new", "load", "cancel"
        if choice == "new" then
            DisplayTextToPlayer(Player(pid), 0, 0, "Creating new soul...")
            if CharacterCreation and CharacterCreation.Begin then
                pcall(CharacterCreation.Begin, pid)
            end
        elseif choice == "load" then
            CharacterCreation_Adapter.LoadSoul(pid, "slot1")
        else
            DisplayTextToPlayer(Player(pid), 0, 0, "Cancelled soul creation.")
        end
    end

    --------------------------------------------------
    -- DevMode commands (for testing)
    --------------------------------------------------
    OnInit.final(function()
        local trigSave = CreateTrigger()
        local trigLoad = CreateTrigger()

        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(trigSave, Player(i), "-savesoul", true)
            TriggerRegisterPlayerChatEvent(trigLoad, Player(i), "-loadsoul", true)
        end

        TriggerAddAction(trigSave, function()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            CharacterCreation_Adapter.SaveSoul(pid)
        end)

        TriggerAddAction(trigLoad, function()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            CharacterCreation_Adapter.LoadSoul(pid, "slot1")
        end)

        if InitBroker and InitBroker.SystemReady then
            InitBroker.SystemReady("CharacterCreation_Adapter")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
