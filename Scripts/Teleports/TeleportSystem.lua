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
    --------------------------------------------------
    -- Config / Sources
    --------------------------------------------------
    local GB = GameBalance or {}

    -- Safe node coordinate fetch
    local function getNodeCoords(id)
        if GB.NODE_COORDS and GB.NODE_COORDS[id] then return GB.NODE_COORDS[id] end
        if GB.HUB_COORDS  and GB.HUB_COORDS[id]  then return GB.HUB_COORDS[id]  end
        if GB.ZONE_COORDS and GB.ZONE_COORDS[id] then return GB.ZONE_COORDS[id] end
        return nil
    end

    -- Identify hubs for hub-tracking logic
    local HUB_SET = {}
    do
        local ids = GB.TELEPORT_NODE_IDS or {}
        local hubs = { ids.YEMMA, ids.KAMI_LOOKOUT }
        for i = 1, #hubs do
            local v = hubs[i]
            if type(v) == "string" and v ~= "" then HUB_SET[v] = true end
        end
    end

    --------------------------------------------------
    -- Helpers / State
    --------------------------------------------------
    local function PD(pid)
        if not PlayerData then PlayerData = {} end
        PlayerData[pid] = PlayerData[pid] or {}
        local pd = PlayerData[pid]
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

    --------------------------------------------------
    -- Unlock / Check
    --------------------------------------------------
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

    --------------------------------------------------
    -- Core Teleport
    --------------------------------------------------
    -- opts = { reason = "string", setHub = bool }
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
        if SetUnitFlyHeight then SetUnitFlyHeight(u, c.z or 0.0, 0.00) end
        PanCameraToTimedForPlayer(Player(pid), c.x or 0.0, c.y or 0.0, 0.15)
        PlayerMenu.Hide(pid)  -- Close travel UI if open
        local pd = PD(pid)
        local forceHub = opts and opts.setHub == true
        if forceHub or HUB_SET[node] then
            pd.lastHubNode = node
        end

        emit("OnTeleportArrive", { pid = pid, node = node, reason = reason })
        return true
    end

    --------------------------------------------------
    -- Export / Import (save system)
    --------------------------------------------------
    function TeleportSystem.Export(pid)
        local pd = PD(pid)
        local out = {}
        for k, v in pairs(pd.unlockedNodes) do if v then out[#out + 1] = k end end
        return out, pd.lastHubNode
    end

    function TeleportSystem.Import(pid, unlockedArray, lastHub)
        local pd = PD(pid)
        pd.unlockedNodes = {}
        if type(unlockedArray) == "table" then
            for i = 1, #unlockedArray do
                local id = unlockedArray[i]
                if type(id) == "string" and id ~= "" then
                    pd.unlockedNodes[id] = true
                end
            end
        end
        if type(lastHub) == "string" and lastHub ~= "" then
            pd.lastHubNode = lastHub
        end
    end

    --------------------------------------------------
    -- Developer Chat Helpers
    --------------------------------------------------
    local function splitSpaces(s)
        local out, acc = {}, ""
        for i = 1, string.len(s or "") do
            local ch = string.sub(s, i, i)
            if ch == " " then
                if string.len(acc) > 0 then out[#out + 1] = acc; acc = "" end
            else
                acc = acc .. ch
            end
        end
        if string.len(acc) > 0 then out[#out + 1] = acc end
        return out
    end

    local function reg(prefix, fn)
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerChatEvent(t, Player(i), prefix, false)
        end
        TriggerAddAction(t, function()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            local msg = GetEventPlayerChatString()
            fn(p, pid, msg)
        end)
    end

    -- -unlock <NODE>
    reg("-unlock ", function(p, pid, msg)
        local rest = string.sub(msg, string.len("-unlock ") + 1)
        local t = splitSpaces(rest)
        local id = t[1]
        if id and id ~= "" then
            if TeleportSystem.Unlock(pid, id) then
                DisplayTextToPlayer(p, 0, 0, "Unlocked travel: " .. tostring(id))
            end
        end
    end)

    -- -tp <NODE>
    reg("-tp ", function(p, pid, msg)
        local rest = string.sub(msg, string.len("-tp ") + 1)
        local t = splitSpaces(rest)
        local id = t[1]
        if id and id ~= "" then
            TeleportSystem.TeleportToNode(pid, id, { reason = "dev_tp" })
        end
    end)

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        if rawget(_G,"InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("TeleportSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
