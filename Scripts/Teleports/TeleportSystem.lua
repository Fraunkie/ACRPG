if Debug and Debug.beginFile then Debug.beginFile("TeleportSystem.lua") end
--==================================================
-- TeleportSystem.lua  (v1.1, 2025-10-26)
-- Core teleport and unlock logic.
-- • Syncs with GameBalance + TeleportConfig
-- • Handles unlocking, checking, and teleporting
-- • Emits ProcBus events:
--      OnTeleportUnlock, OnTeleportDepart, OnTeleportArrive
--==================================================

if not TeleportSystem then TeleportSystem = {} end
_G.TeleportSystem = TeleportSystem

do
    -- Config / Sources
    local GB = GameBalance or {}

    -- Safe node coordinate fetch (fetch from GameBalance)
    local function getNodeCoords(id)
        if GameBalance.COORDS and GameBalance.COORDS[id] then
            return GameBalance.COORDS[id]  -- Fetch from GameBalance.COORDS
        end
        return nil  -- Return nil if no coordinates found
    end

    -- Identify hubs for hub-tracking logic
    local HUB_SET = {}
    do
        local ids = GB.TELEPORT_NODE_IDS or {}
        local hubs = { ids.YEMMA, ids.KAMI_LOOKOUT, ids.HFIL }  -- Add other hubs here if needed
        for i = 1, #hubs do
            local v = hubs[i]
            if type(v) == "string" and v ~= "" then HUB_SET[v] = true end
        end
    end

    -- Helpers / State
    local function PD(pid)
        if not PLAYER_DATA then PLAYER_DATA = {} end
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        local pd = PLAYER_DATA[pid]
        pd.unlockedNodes = pd.unlockedNodes or {}
        return pd
    end

    local function isValidPlayer(pid)
        return pid and pid >= 0 and pid < bj_MAX_PLAYERS
    end

    local function hero(pid)
        local pd = PD(pid)
        if pd.hero and GetUnitTypeId(pd.hero) ~= 0 then return pd.hero end
        if _G.PlayerHero and PlayerHero[pid] and GetUnitTypeId(PlayerHero[pid]) ~= 0 then
            pd.hero = PlayerHero[pid]
            return pd.hero
        end
        return nil
    end

    local function emit(evt, payload)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then pcall(PB.Emit, evt, payload) end
    end

    -- Unlock / Check
    function TeleportSystem.Unlock(pid, node)
        if not isValidPlayer(pid) then return false end
        if type(node) ~= "string" or node == "" then return false end
        local pd = PD(pid)
        if pd.unlockedNodes[node] then return true end
        pd.unlockedNodes[node] = true
        emit("OnTeleportUnlock", { pid = pid, node = node, source = "api" })
        return true
    end

    function TeleportSystem.IsUnlocked(pid, node)
        if not isValidPlayer(pid) then return false end
        local pd = PD(pid)
        return pd.unlockedNodes[node] and true or false
    end

    -- Core Teleport
    function TeleportSystem.TeleportToNode(pid, node, opts)
        if not isValidPlayer(pid) then return false end
        if type(node) ~= "string" or node == "" then return false end

        local u = hero(pid)
        if not u then return false end

        if not TeleportSystem.IsUnlocked(pid, node) then
            TeleportSystem.Unlock(pid, node)
        end

        local c = getNodeCoords(node)
        if not c then
            DisplayTextToPlayer(Player(pid), 0, 0, "Unknown teleport destination: " .. tostring(node))
            return false
        end

        local reason = opts and opts.reason or "teleport"
        emit("OnTeleportDepart", { pid = pid, node = node, reason = reason })

        SetUnitPosition(u, c.x or 0.0, c.y or 0.0)
        SetUnitFlyHeight(u, 0, 0)
    

        local pd = PD(pid)
        local forceHub = opts and opts.setHub == true
        if forceHub or HUB_SET[node] then
            pd.lastHubNode = node
        end
        emit("OnTeleportArrive", { pid = pid, node = node, reason = reason })

        -- ** Restore Direct Control Mode after teleportation **
        if _G.ProcBus and ProcBus.Emit then
          --  ProcBus.Emit("DirectControlToggled", { pid = pid, enabled = true })
        end

        -- ** Restore Camera Control after teleportation **
       -- if _G.CameraWheelGrid and CameraWheelGrid.camTick then
        --    CameraWheelGrid.camTick()  -- Re-activate camera controls
       -- end

        return true
    end

    -- Init
    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("TeleportSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
