if Debug and Debug.beginFile then Debug.beginFile("LivesSystem.lua") end
--==================================================
-- LivesSystem.lua
-- Tracks player lives and death behavior.
-- Only acts on the player's hero.
-- Dungeons:
--   - On death: hero stays dead (awaiting choice).
--   - If the player chooses to revive (ConfirmDungeonRevive), spend 1 life and revive at the dungeon entrance (inside).
--   - If the player has 0 lives, send to Yemma on death.
-- Overworld:
--   - On death: send to Yemma. If the player has at least 1 life, spend 1 life.
--==================================================

if not LivesSystem then LivesSystem = {} end
_G.LivesSystem = LivesSystem

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local GB            = GameBalance or {}
    local STARTING      = (GB.LIVES and GB.LIVES.STARTING_LIVES) or 3
    local MAX_LIVES     = (GB.LIVES and GB.LIVES.MAX_LIVES) or 5
    local RESPAWN_DELAY = 5.0

    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- P[pid] = { lives, max, pendingRespawn, awaitingChoice, inDungeon, dngX, dngY }
    local P = {}

    -- Global dungeon fallback (can be driven by ProcBus; per-player flag overrides this)
    local GLOBAL_IN_DUNGEON = false

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(msg)
        if Debug and Debug.printf then
            Debug.printf("[Lives] " .. tostring(msg))
        end
    end

    local function PD(pid)
        local t = P[pid]
        if not t then
            t = {
                lives = STARTING,
                max = MAX_LIVES,
                pendingRespawn = false,
                awaitingChoice = false,
                inDungeon = false,
                dngX = nil, dngY = nil
            }
            P[pid] = t
        end
        return t
    end

    local function clamp(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end

    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, e) end
    end

    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function getHero(pid)
        if not PLAYER_DATA then PLAYER_DATA = {} end
        local pd = PLAYER_DATA[pid] or {}
        if validUnit(pd.hero) then return pd.hero end
        if _G.PlayerHero and validUnit(_G.PlayerHero[pid]) then return _G.PlayerHero[pid] end
        return nil
    end

    local function isSameHandle(a, b)
        return a and b and GetHandleId(a) == GetHandleId(b)
    end

    local function safeRevive(u, x, y)
        if not validUnit(u) then return end
        ReviveHero(u, x, y, true)
        SetUnitState(u, UNIT_STATE_MANA, GetUnitState(u, UNIT_STATE_MAX_MANA))
        IssueImmediateOrder(u, "stop")
    end

    local function hubRevivePoint()
        local HC = GB.HUB_COORDS or {}
        local ye = HC.YEMMA
        if ye then return ye.x or 0.0, ye.y or 0.0 end
        return 0.0, 0.0
    end

    local function isInDungeon(pid)
        local t = PD(pid)
        if t.inDungeon ~= nil then return t.inDungeon end
        return GLOBAL_IN_DUNGEON
    end

    local function dungeonEntrancePoint(pid)
        local t = PD(pid)
        if t.dngX and t.dngY then return t.dngX, t.dngY end
        local DC = GB.DUNGEON_ENTRANCE or {}
        if DC.x and DC.y then return DC.x, DC.y end
        return hubRevivePoint()
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function LivesSystem.Get(pid)
        local t = PD(pid)
        return t.lives, t.max
    end

    function LivesSystem.Set(pid, value)
        local t = PD(pid)
        local nv = clamp(math.floor(value or 0), 0, t.max)
        if nv == t.lives then return t.lives end
        t.lives = nv
        emit("OnLivesChanged", { pid = pid, lives = t.lives, max = t.max })
        dprint("player " .. tostring(pid) .. " lives set to " .. tostring(t.lives))
        return t.lives
    end

    function LivesSystem.Add(pid, delta)
        local t = PD(pid)
        local nv = clamp((t.lives or 0) + math.floor(delta or 0), 0, t.max)
        if nv == t.lives then return t.lives end
        t.lives = nv
        emit("OnLivesChanged", { pid = pid, lives = t.lives, max = t.max })
        dprint("player " .. tostring(pid) .. " lives now " .. tostring(t.lives))
        return t.lives
    end

    function LivesSystem.SetMax(pid, newMax, keepRatio)
        local t = PD(pid)
        local oldMax = t.max
        t.max = math.max(1, math.floor(newMax or MAX_LIVES))
        if keepRatio and oldMax > 0 then
            local ratio = t.lives / oldMax
            t.lives = clamp(math.floor(ratio * t.max + 0.5), 0, t.max)
        else
            t.lives = clamp(t.lives, 0, t.max)
        end
        emit("OnLivesChanged", { pid = pid, lives = t.lives, max = t.max })
    end

    function LivesSystem.CanRespawn(pid)
        local t = PD(pid)
        return (t.lives or 0) > 0
    end

    -- Per-player dungeon flag
    function LivesSystem.SetDungeon(pid, flag)
        PD(pid).inDungeon = flag and true or false
        dprint("player " .. tostring(pid) .. " inDungeon set to " .. tostring(PD(pid).inDungeon))
    end

    -- Set per-player dungeon entrance revive point (inside)
    function LivesSystem.SetDungeonEntrance(pid, x, y)
        local t = PD(pid)
        t.dngX = x
        t.dngY = y
        dprint("player " .. tostring(pid) .. " dungeon entrance set")
    end

    -- Call when the player chooses to spend a life inside a dungeon
    function LivesSystem.ConfirmDungeonRevive(pid)
        local t = PD(pid)
        if not isInDungeon(pid) then return end
        if not t.awaitingChoice then return end
        if (t.lives or 0) <= 0 then
            t.awaitingChoice = false
            local hx, hy = hubRevivePoint()
            local hero = getHero(pid)
            TimerStart(CreateTimer(), RESPAWN_DELAY, false, function()
                if validUnit(hero) then
                    safeRevive(hero, hx, hy)
                end
                if _G.TeleportSystem then
                    local node = GB.TELEPORT_NODE_IDS and GB.TELEPORT_NODE_IDS.YEMMA or "YEMMA"
                    if node then
                        TeleportSystem.Unlock(pid, node)
                        TeleportSystem.TeleportToNode(pid, node, { reason = "lives_respawn" })
                    end
                end
                DestroyTimer(GetExpiredTimer())
            end)
            return
        end

        t.awaitingChoice = false
        LivesSystem.Add(pid, -1)

        local dx, dy = dungeonEntrancePoint(pid)
        local hero = getHero(pid)
        TimerStart(CreateTimer(), RESPAWN_DELAY, false, function()
            if validUnit(hero) then
                safeRevive(hero, dx, dy)
            end
            DestroyTimer(GetExpiredTimer())
        end)
    end

    --------------------------------------------------
    -- Internal actions
    --------------------------------------------------
    local function sendToYemma(pid, consumeLife)
        local t = PD(pid)
        if t.pendingRespawn then return end
        t.pendingRespawn = true

        if consumeLife and (t.lives or 0) > 0 then
            LivesSystem.Add(pid, -1)
        end

        local x, y = hubRevivePoint()
        TimerStart(CreateTimer(), RESPAWN_DELAY, false, function()
            local hero = getHero(pid)
            if validUnit(hero) then
                safeRevive(hero, x, y)
            end
            if _G.TeleportSystem then
                local node = GB.TELEPORT_NODE_IDS and GB.TELEPORT_NODE_IDS.YEMMA or "YEMMA"
                if node then
                    TeleportSystem.Unlock(pid, node)
                    TeleportSystem.TeleportToNode(pid, node, { reason = "lives_respawn" })
                end
            end
            t.pendingRespawn = false
            DestroyTimer(GetExpiredTimer())
        end)
    end

    local function handleDeathOverworld(pid)
        local t = PD(pid)
        local hasLives = (t.lives or 0) > 0
        sendToYemma(pid, hasLives)
    end

    local function handleDeathDungeon(pid)
        local t = PD(pid)
        if (t.lives or 0) <= 0 then
            DisplayTextToPlayer(Player(pid), 0, 0, "No lives left. Returning to Yemma.")
            sendToYemma(pid, false)
            return
        end
        t.awaitingChoice = true
        emit("OnDungeonDeathAwaitingChoice", { pid = pid })
        DisplayTextToPlayer(Player(pid), 0, 0, "You are dead in a dungeon. Choose to revive to spend one life.")
    end

    --------------------------------------------------
    -- Wiring (ProcBus only; no chat)
    --------------------------------------------------
    local function wireBus()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnHeroDeath", function(e)
                if not e then return end
                if e.pid == nil then return end
                if not e.unit then return end
                local pid = e.pid
                local hero = getHero(pid)
                if not validUnit(hero) then return end
                if not isSameHandle(hero, e.unit) then return end

                if isInDungeon(pid) then
                    handleDeathDungeon(pid)
                else
                    handleDeathOverworld(pid)
                end
            end)

            -- Optional global dungeon fallback: toggle via boss events
            PB.On("BOSS_PULL_START", function() GLOBAL_IN_DUNGEON = true end)
            PB.On("BOSS_PULL_END",   function() GLOBAL_IN_DUNGEON = false end)
            PB.On("BOSS_DEFEATED",   function() GLOBAL_IN_DUNGEON = false end)
            PB.On("DUNGEON_WIPE",    function() GLOBAL_IN_DUNGEON = true end)
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        local i = 0
        while i < bj_MAX_PLAYERS do
            local t = PD(i)
            emit("OnLivesChanged", { pid = i, lives = t.lives, max = t.max })
            i = i + 1
        end
        wireBus()
        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("LivesSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
