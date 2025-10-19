if Debug and Debug.beginFile then Debug.beginFile("BootFlow_StartHandler.lua") end

if not BootFlow then BootFlow = {} end
_G.BootFlow = BootFlow

do
    local GB   = GameBalance or {}
    local IDS  = (GB.TELEPORT_NODE_IDS) or {}

    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function PD(pid)
        if not PLAYER_DATA then PLAYER_DATA = {} end
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end

    local function ensureHero(pid)
        local pd = PD(pid)
        if ValidUnit(pd.hero) then return pd.hero end
        if _G.PlayerHero and ValidUnit(PlayerHero[pid]) then
            pd.hero = PlayerHero[pid]
            return pd.hero
        end
        return nil
    end

    local function startCharacterCreation(pid)
        -- prefer adapter if present
        if _G.CharacterCreation_Adapter and CharacterCreation_Adapter.Start then
            pcall(CharacterCreation_Adapter.Start, pid, function()
                local pd = PD(pid)
                pd.yemmaIntroPending = true
            end)
            Debug.try(function() Debug.printf("[BootFlow] Using CharacterCreation_Adapter for player %d\n", pid) end)
            return
        end

        -- fallback to classic CC
        if _G.CharacterCreation and CharacterCreation.Start then
            pcall(CharacterCreation.Start, pid, function()
                local pd = PD(pid)
                pd.yemmaIntroPending = true
            end)
            Debug.try(function() Debug.printf("[BootFlow] Using fallback CharacterCreation for player %d\n", pid) end)
            return
        end

        -- if no creator available, just mark pending
        PD(pid).yemmaIntroPending = true
        Debug.try(function() Debug.printf("[BootFlow] No character creator available for player %d\n", pid) end)
    end

    function BootFlow.BeginForPlayer(pid)
        -- 1) ensure hero exists or is being created
        local h = ensureHero(pid)
        if not h then
            Debug.try(function() Debug.printf("[BootFlow] Player %d does not have a hero, starting character creation\n", pid) end)
            startCharacterCreation(pid)
        else
            -- already has a hero: still mark intro pending on first session
            local pd = PD(pid)
            if not pd.yemmaIntroSeen then
                pd.yemmaIntroPending = true
                Debug.try(function() Debug.printf("[BootFlow] Player %d already has a hero, marking Yemma intro pending\n", pid) end)
            end
        end

        -- 2) make sure Yemma node is known
        if _G.TeleportSystem and TeleportSystem.Unlock then
            TeleportSystem.Unlock(pid, IDS.YEMMA or "YEMMA")
            Debug.try(function() Debug.printf("[BootFlow] Unlocked Yemma node for player %d\n", pid) end)
        end
    end

    OnInit.final(function()
        -- bootstrap all human player slots
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerSlotState(Player(pid)) == PLAYER_SLOT_STATE_PLAYING then
                BootFlow.BeginForPlayer(pid)
                Debug.try(function() Debug.printf("[BootFlow] Initialized for player %d\n", pid) end)
            end
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("BootFlow_StartHandler")
            Debug.try(function() Debug.printf("[BootFlow] BootFlow_StartHandler initialization complete\n") end)
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
