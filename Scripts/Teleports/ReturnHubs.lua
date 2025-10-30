if Debug and Debug.beginFile then Debug.beginFile("ZoneTeleporterNPC.lua") end
--==================================================
-- ZoneTeleporterNPC.lua
-- Version: v1.2 (2025-10-26)
-- Universal return teleporter placed in zones/raids.
-- • Walk into radius → auto return to last hub
-- • Or press F → TryReturnNearby(pid) to return if near crystal
-- • Crystal unit id: h0CH
-- • Tracks currentZone via TeleportSystem OnTeleportArrive
--==================================================

if not ZoneTeleporterNPC then ZoneTeleporterNPC = {} end
_G.ZoneTeleporterNPC = ZoneTeleporterNPC

do
    -- Config
    local UNIT_ID       = FourCC("h0CH")   -- crystal unit
    local INTERACT_R    = 300.0
    local PROMPT_DELAY  = 0.25

    -- State
    local returns = {} -- originId -> destId
    local known   = {} -- pid -> last origin node string

    -- Helpers
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[ZoneTP] " .. tostring(s)) end
    end
    local function PD(pid)
        if not PlayerData then PlayerData = {} end
        PlayerData[pid] = PlayerData[pid] or {}
        return PlayerData[pid]
    end
    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function ids()
        local GB = GameBalance or {}
        return (GB.TELEPORT_NODE_IDS) or {}
    end
    local function pretty(id)
        local GB = GameBalance or {}
        if GB.NODE_PRETTY and GB.NODE_PRETTY[id] then return GB.NODE_PRETTY[id] end
        return tostring(id)
    end
    local function setReturn(origin, dest)
        if not origin or origin == "" or not dest or dest == "" then return end
        returns[origin] = dest
    end

    -- Public API
    function ZoneTeleporterNPC.MapReturn(origin, dest) setReturn(origin, dest) end

    -- Track current zone using TeleportSystem event
    local function wireBus()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnTeleportArrive", function(e)
                if not e or e.pid == nil then return end
                if type(e.node) ~= "string" then return end
                known[e.pid] = e.node
                local pd = PD(e.pid)
                pd.currentZone = e.node      -- keep player data synced for UI
                pd.lastHubNode = pd.lastHubNode or (ids().YEMMA or "YEMMA")
            end)
        end
    end

    -- Resolve destination hub
    local function resolveReturn(pid)
        local node = known[pid]
        local dest = nil
        if node and returns[node] then dest = returns[node] end
        if not dest then
            local pd = PD(pid)
            if type(pd.lastHubNode) == "string" and pd.lastHubNode ~= "" then
                dest = pd.lastHubNode
            end
        end
        if not dest then
            dest = ids().YEMMA or ids().KAMI_LOOKOUT or "YEMMA"
        end
        return dest
    end

    local function doReturn(pid)
        local dest = resolveReturn(pid)
        if _G.TeleportSystem and TeleportSystem.TeleportToNode then
            TeleportSystem.Unlock(pid, dest)
            TeleportSystem.TeleportToNode(pid, dest, { reason = "zone_return" })
        end
    end

    -- Manual key-triggered return (used by F)
    function ZoneTeleporterNPC.TryReturnNearby(pid)
        local pd = PD(pid)
        local hero = pd.hero or (_G.PlayerHero and PlayerHero[pid]) or nil
        if not validUnit(hero) then return end

        local hx, hy = GetUnitX(hero), GetUnitY(hero)
        local g = CreateGroup()
        GroupEnumUnitsOfPlayer(g, Player(PLAYER_NEUTRAL_PASSIVE), nil)
        local found = false
        while true do
            local u = FirstOfGroup(g)
            if not u then break end
            GroupRemoveUnit(g, u)
            if validUnit(u) and GetUnitTypeId(u) == UNIT_ID then
                local dx = GetUnitX(u) - hx
                local dy = GetUnitY(u) - hy
                if dx*dx + dy*dy <= (INTERACT_R * INTERACT_R) then
                    found = true
                    break
                end
            end
        end
        DestroyGroup(g)
        if found then doReturn(pid) end
    end

    -- Auto proximity loop (walk-in auto return)
    local function poll()
        local g = CreateGroup()
        GroupEnumUnitsOfPlayer(g, Player(PLAYER_NEUTRAL_PASSIVE), nil)
        local list = {}
        while true do
            local u = FirstOfGroup(g)
            if not u then break end
            GroupRemoveUnit(g, u)
            if validUnit(u) and GetUnitTypeId(u) == UNIT_ID then
                list[#list + 1] = u
            end
        end
        DestroyGroup(g)

        if #list == 0 then return end

        for pid = 0, bj_MAX_PLAYERS - 1 do
            local pd = PD(pid)
            local hero = pd.hero or (_G.PlayerHero and PlayerHero[pid]) or nil
            if validUnit(hero) and GetWidgetLife(hero) > 0.405 then
                local hx, hy = GetUnitX(hero), GetUnitY(hero)
                for i = 1, #list do
                    local tu = list[i]
                    local dx = GetUnitX(tu) - hx
                    local dy = GetUnitY(tu) - hy
                    if dx*dx + dy*dy <= (INTERACT_R * INTERACT_R) then
                        doReturn(pid)
                        break
                    end
                end
            end
        end
    end

    -- Dev helpers
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
    local function reg(cmd, fn)
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerChatEvent(t, Player(i), cmd, false)
        end
        TriggerAddAction(t, function()
            fn(GetTriggerPlayer(), GetPlayerId(GetTriggerPlayer()), GetEventPlayerChatString())
        end)
    end
    reg("-sethub ", function(p, pid, msg)
        local rest = string.sub(msg, string.len("-sethub ") + 1)
        local t = splitSpaces(rest)
        if #t >= 1 then
            PD(pid).lastHubNode = t[1]
            DisplayTextToPlayer(p, 0, 0, "Hub set to " .. pretty(t[1]))
        end
    end)
    reg("-returnto", function(p, pid, msg) doReturn(pid) end)

    -- Init
    OnInit.final(function()
        if _G.TeleportConfig and TeleportConfig.GetAll then
            local all = TeleportConfig.GetAll()
            if all and all.RETURNS then
                for k, v in pairs(all.RETURNS) do setReturn(k, v) end
            end
        end
        wireBus()
        TimerStart(CreateTimer(), PROMPT_DELAY, true, poll)
        dprint("ready; crystal h0CH enables zone returns")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ZoneTeleporterNPC")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
