if Debug and Debug.beginFile then Debug.beginFile("CharacterCreation.lua") end
--==================================================
-- CharacterCreation.lua
-- • Creates the player's soul at configured spawn
-- • Selects the hero + moves camera (LOCAL to player)
--==================================================

if not CharacterCreation then CharacterCreation = {} end
_G.CharacterCreation = CharacterCreation

do
    if not PLAYER_DATA then PLAYER_DATA = {} end

    local function PD(pid)
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end

    -- Resolve spawn (supports either GameBalance.SPAWN or HUB_COORDS.SPAWN)
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

    -- Resolve starting unit id (SOUL/START_HERO_ID with H001 fallback)
    local function readSoulId()
        if GameBalance then
            if GameBalance.SOUL and GameBalance.SOUL ~= "" then return GameBalance.SOUL end
            if GameBalance.START_HERO_ID and GameBalance.START_HERO_ID ~= "" then return GameBalance.START_HERO_ID end
        end
        return "H001"
    end

    function CharacterCreation.Begin(pid)
        local pd = PD(pid)

        if pd.hero then
            DisplayTextToPlayer(Player(pid), 0, 0, "Soul already created.")
            return
        end

        local spawnX, spawnY = readSpawnXY()
        local soulId         = readSoulId()

        local hero = CreateUnit(Player(pid), FourCC(soulId), spawnX, spawnY, 270.0)
        pd.hero = hero
        if _G.PlayerHero then PlayerHero[pid] = hero end
        pd.isInitialized    = true
        pd.bootflow_active  = false
        pd.yemmaIntroPending = false

        DisplayTextToPlayer(Player(pid), 0, 0, "Soul successfully created.")

        -- >>> LOCAL-ONLY camera + selection for the owning player <<<
        if GetLocalPlayer() == Player(pid) then
            -- gentle pan; SetCameraPosition works too, but PanCameraToTimed is nicer
            PanCameraToTimed(spawnX, spawnY, 0.35)
            ClearSelection()
            SelectUnit(hero, true)
        end
        -- ^ never read camera/selection state outside local blocks

        if ProcBus and ProcBus.Emit then
            ProcBus.Emit("OnHeroCreated", { pid = pid, unit = hero })
        end
    end

    function CharacterCreation.ShowMenu(pid)
        if PLAYER_DATA[pid] and PLAYER_DATA[pid].isInitialized then
            DisplayTextToPlayer(Player(pid), 0, 0, "You have already created a soul.")
            return
        end
        if CharacterCreation_UI and CharacterCreation_UI.ShowMenu then
            CharacterCreation_UI.ShowMenu(pid)
        end
    end

    OnInit.final(function()
        local trig = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-create", true)
        end
        TriggerAddAction(trig, function()
            local p = GetTriggerPlayer()
            CharacterCreation.Begin(GetPlayerId(p))
        end)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CharacterCreation")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
