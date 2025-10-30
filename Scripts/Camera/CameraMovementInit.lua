if Debug and Debug.beginFile then Debug.beginFile("CameraMovement_Init.lua") end
--==================================================
-- CameraMovement_Init.lua
-- • Binds camera + control to the player's hero as soon as it exists
-- • Re-binds on later hero changes (respawn/ascension) via ProcBus "HeroAssigned"
-- • Sets default shoulder offset unless already defined in PlayerData
-- • Enables SCS (WASD) and keeps RMB context orders locked (handled in SCS.lua)
--==================================================

CameraMovement = CameraMovement or {}
_G.CameraMovement = CameraMovement

do
    --------------------------------------------------
    -- Utils
    --------------------------------------------------
    local function valid(u) return u and GetUnitTypeId(u) ~= 0 end
    local function heroOf(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]
        if pd and valid(pd.hero) then return pd.hero end
        if _G.PlayerHero and valid(PlayerHero[pid]) then return PlayerHero[pid] end
        return nil
    end

    --------------------------------------------------
    -- Public: explicit bind (call if you assign hero manually)
    --------------------------------------------------
    function CameraMovement.InitFor(pid, u)
        if not valid(u) then return end

        -- Mirror into PlayerData (authoritative)
        if PlayerData and PlayerData.SetHero then PlayerData.SetHero(pid, u) end

        -- Ensure a sensible shoulder is set once
        do
            local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]
            if pd then
                pd.control = pd.control or {}
                if pd.control.shoulder == nil then
                    pd.control.shoulder = 120.0 -- right-shoulder default; set negative for left
                end
            end
        end

        -- Hook up movement (SCS) and enable control
        if SCS and SCS.Associate then SCS.Associate(u, Player(pid), 22, false) end
        if SCS and SCS.SetControl  then SCS.SetControl(Player(pid), true) end

        -- Local camera follow; shoulder offset is applied each tick by CameraWheel.lua
        if GetLocalPlayer() == Player(pid) then
            SetCameraTargetController(u, 0.0, 0.0, false)
            CameraSetSmoothingFactor(1)
        end

        -- Belt-and-suspenders: keep control on shortly after
        TimerStart(CreateTimer(), 0.25, false, function()
            if SCS and SCS.SetControl then SCS.SetControl(Player(pid), true) end
        end)
    end

    --------------------------------------------------
    -- Auto-binder: waits for hero, binds once, rebinds on events
    --------------------------------------------------
    OnInit.final(function()
        local bound = {}

        local function tryBind(pid)
            if bound[pid] then return end
            local u = heroOf(pid)
            if u then
                CameraMovement.InitFor(pid, u)
                bound[pid] = true
            end
        end

        -- Poll every 0.10s until each human player has a hero; then stop
        TimerStart(CreateTimer(), 0.10, true, function()
            local pending = false
            for pid = 0, bj_MAX_PLAYERS - 1 do
                if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                    if not bound[pid] then
                        tryBind(pid)
                        if not bound[pid] then pending = true end
                    end
                end
            end
            if not pending then PauseTimer(GetExpiredTimer()) end
        end)

        -- Rebind on late assignment (if your systems emit this)
        if _G.ProcBus and ProcBus.On then
            ProcBus.On("HeroAssigned", function(ev)
                if ev and ev.pid ~= nil and valid(ev.unit) then
                    bound[ev.pid] = false
                    tryBind(ev.pid)
                end
            end)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CameraMovement_Init")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
