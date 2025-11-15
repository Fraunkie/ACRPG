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

    -- Resolve spawn (supports SPAWN in multiple layouts)
    local function readSpawnXY()
        if GameBalance then
            if GameBalance.COORDS and GameBalance.COORDS.SPAWN then
                return GameBalance.COORDS.SPAWN.x or 0, GameBalance.COORDS.SPAWN.y or 0
            end
        end
        return 0, 0
    end

    -- Resolve starting unit id (string or number), safe for CreateUnit
    local function readSoulId()
        if GameBalance then
            if GameBalance.SOUL and GameBalance.SOUL ~= "" then return GameBalance.SOUL end
            if GameBalance.START_HERO_ID and GameBalance.START_HERO_ID ~= "" then return GameBalance.START_HERO_ID end
        end
        return "H001"
    end

    local function toUnitId(v)
        if type(v) == "number" then return v end
        if type(v) == "string" then
            local ok, id = pcall(FourCC, v)
            if ok and id and id ~= 0 then return id end
        end
        return FourCC("H001")
    end


    local function test(unit)
    local data = ALICE_PairLoadData()
    local dist = ALICE_PairGetDistance2D()
    local u = ALICE_GetAnchor(unit)
    local pid = GetPlayerId(GetOwningPlayer(u))

    if dist < 500 then
        if ALICE_PairIsFirstContact() then
            DisplayTextToPlayer(Player(pid), 0, 0, "working")

            -- Only call CreateAscensionForPlayer if the player has a charged shard
            if ShardChargeSystem.HasChargedShard(pid) then
                -- Call CreateAscensionForPlayer from the other script
                CreateAscensionForPlayer(pid)  -- Simply call without passing itemid
            end
        end
    else
        ALICE_PairReset()
    end
end

    

    function CharacterCreation.Begin(pid)
        local pd = PD(pid)
        if pd.hero then
            DisplayTextToPlayer(Player(pid), 0, 0, "Soul already created.")
            return
        end

        local spawnX, spawnY = readSpawnXY()
        local soulRaw        = readSoulId()
        local unitId         = toUnitId(soulRaw)

        -- Optional dev print
        if rawget(_G, "DevMode") and DevMode.IsOn and DevMode.IsOn() then
            print("[Create] pid " .. pid .. " unitId " .. tostring(unitId) .. " x " .. tostring(spawnX) .. " y " .. tostring(spawnY))
        end

        local hero = CreateUnit(Player(pid), unitId, spawnX, spawnY, 270.0)
        pd.hero = hero
        if _G.PlayerHero then PlayerHero[pid] = hero end
        pd.isInitialized     = true
        pd.bootflow_active   = false
        pd.yemmaIntroPending = false
        CustomSpellBar.BindHero(pid, hero)
        HeroStatSystem.InitializeStats(pid, hero)
        HeroStatSystem.Recalculate(pid)
        CTT.SetTrees(Player(pid),"Lost Soul")

        DisplayTextToPlayer(Player(pid), 0, 0, "Soul successfully created.")

        -- Local camera + selection
        if GetLocalPlayer() == Player(pid) then
            PanCameraToTimed(spawnX, spawnY, 0.35)
            ClearSelection()
            SelectUnit(hero, true)
        end

        if ProcBus and ProcBus.Emit then
            ProcBus.Emit("OnHeroCreated", { pid = pid, unit = hero })
        end

        -- Add ALICE Actor to Hero Unit
        local actorData = {
            identifier = "heroActor", -- Unique identifier for the actor
            interactions = {h004 = test},  -- Define interactions, like being near an object
            flags =  {radius = 500, anchor = hero}

        }

        
        ALICE_Create(hero, actorData.identifier, actorData.interactions)

       -- ALICE_SetFlag(CAT_Camera.identifier, "anchor", hero)
        print("Hero actor added to unit.")
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
