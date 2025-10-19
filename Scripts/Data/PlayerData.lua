if Debug and Debug.beginFile then Debug.beginFile("PlayerData.lua") end
--==================================================
-- PlayerData.lua
-- Canonical per-player runtime store and helpers
-- Adds onboarding flags for Yemma Choice flow
--==================================================

do
    PlayerData = PlayerData or {}
    _G.PlayerData = PlayerData

    -- Public: get or create the per-player table
    function PlayerData.Get(pid)
        if not PLAYER_DATA then PLAYER_DATA = {} end
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or PlayerData._defaultTable()
        return PLAYER_DATA[pid]
    end

    -- Public: shallow set helper
    function PlayerData.Set(pid, key, value)
        local t = PlayerData.Get(pid)
        t[key] = value
        return t[key]
    end

    -- Public: get helper with default fallback
    function PlayerData.GetField(pid, key, defaultValue)
        local t = PlayerData.Get(pid)
        local v = t[key]
        if v == nil then
            return defaultValue
        end
        return v
    end
    
    -- Public: resets only the Yemma Choice onboarding flags for this player
    function PlayerData.ResetStartFlags(pid)
        local t = PlayerData.Get(pid)
        t.hasStarted = false
        t.introChoice = nil
        t.yemmaPromptShown = false
        t.yemmaPromptMinimized = false
        t.introCompleted = false -- Track if the intro is completed
        t.introStyle = nil      -- Store selected intro style (e.g., "Full" or "Skip")
    end

    -- Internal: default per-player table
    function PlayerData._defaultTable()
        return {
            hero = nil,
            tier = 0,
            role = "NONE",
            zone = "YEMMA",
            powerLevel = 0,
            soulEnergy = 0,
            fragments = 0,
            ownedShards = {},
            spiritDrive = 0,
            lootChatEnabled = true,

            -- Onboarding flags for the Yemma Choice flow
            hasStarted = false,
            introChoice = nil,  -- Track the intro style choice
            yemmaPromptShown = false,
            yemmaPromptMinimized = false,

            -- Intro-related flags
            introCompleted = false, -- Whether the intro has been completed
            introStyle = nil,      -- The chosen intro style ("Full" or "Skip")

            -- Session flags reserved for Teleport and Hub flows
            teleports = {},
        }
    end

    -- Ensure all player tables exist at startup
    OnInit.final(function()
        if not PLAYER_DATA then PLAYER_DATA = {} end
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                PLAYER_DATA[pid] = PLAYER_DATA[pid] or PlayerData._defaultTable()
            end
        end
        print("[PlayerData] Initialized per-player tables")
    end)

end

if Debug and Debug.endFile then Debug.endFile() end
