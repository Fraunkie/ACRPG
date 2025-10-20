if Debug and Debug.beginFile then Debug.beginFile("PlayerMenu.lua") end
--==================================================
-- PlayerMenu.lua
-- Adjusted background handling to prevent distortion
--==================================================

do
    --------------------------------------------------
    -- Module
    --------------------------------------------------
    PlayerMenu = PlayerMenu or {}
    _G.PlayerMenu = PlayerMenu

    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local BG_PATH = "war3mapImported\\MenuBackground.blp"  -- Your custom image
    local START_W = 0.46    -- Frame width (tuned size)
    local START_H = 0.46    -- Keep aspect ratio for square background (if 512x512)
    local DEBOUNCE = 0.25

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local state = {}          -- state[pid] = { created, isOpen, root, debounce }
    local parent = nil        -- game UI root

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function GetHero(pid)
        if PlayerData and PlayerData.GetHero then
            return PlayerData.GetHero(pid)
        end
        if _G.PLAYER_DATA and _G.PLAYER_DATA[pid] then
            return _G.PLAYER_DATA[pid].hero
        end
        return nil
    end

    local function ValidUnit(u)
        return u ~= nil and GetUnitTypeId(u) ~= 0
    end

    local function EnsureState(pid)
        if not state[pid] then
            state[pid] = {
                created = false,
                isOpen = false,
                root = nil,
                debounce = false,
            }
        end
        return state[pid]
    end

    --------------------------------------------------
    -- Core UI
    --------------------------------------------------
    function PlayerMenu.CreateFrames(pid)
        local S = EnsureState(pid)
        if S.created then return end

        local root = BlzCreateFrameByType("BACKDROP", "PlayerMenuRoot", parent, "", 0)
        BlzFrameSetSize(root, START_W, START_H)
        BlzFrameSetAbsPoint(root, FRAMEPOINT_CENTER, 0.40, 0.36)  -- Centered
        BlzFrameSetTexture(root, BG_PATH, 0, true)
        BlzFrameSetVisible(root, false)

        S.root = root
        S.created = true
    end

    function PlayerMenu.Show(pid)
        local S = EnsureState(pid)
        if not S.created then PlayerMenu.CreateFrames(pid) end
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(S.root, true)
        end
        S.isOpen = true
    end

    function PlayerMenu.Hide(pid)
        local S = EnsureState(pid)
        if S.created and GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(S.root, false)
        end
        S.isOpen = false
    end

    function PlayerMenu.Toggle(pid)
        local S = EnsureState(pid)
        DisplayTextToPlayer(Player(pid), 0, 0, "[Debug] L pressed")

        local u = GetHero(pid)
        if not ValidUnit(u) then
            return
        end

        if not S.created then
            PlayerMenu.CreateFrames(pid)
            PlayerMenu.Show(pid)
            return
        end

        if S.isOpen then
            PlayerMenu.Hide(pid)
        else
            PlayerMenu.Show(pid)
        end
    end

    --------------------------------------------------
    -- Input binding and debounce
    --------------------------------------------------
    local function OnKeyDownL(pid)
        local S = EnsureState(pid)
        if S.debounce then return end
        S.debounce = true

        PlayerMenu.Toggle(pid)

        local t = CreateTimer()
        TimerStart(t, DEBOUNCE, false, function()
            S.debounce = false
            DestroyTimer(t)
        end)
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        parent = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)

        -- Register OSKEY_L for all players
        for pid = 0, bj_MAX_PLAYERS - 1 do
            local trig = CreateTrigger()
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_L, 0, true)
            TriggerAddAction(trig, function()
                local p = GetTriggerPlayer()
                local id = GetPlayerId(p)
                OnKeyDownL(id)
            end)
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
