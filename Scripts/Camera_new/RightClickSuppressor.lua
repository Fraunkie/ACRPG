if Debug and Debug.beginFile then Debug.beginFile("RightClickSuppressor.lua") end
--==================================================
-- RightClickSuppressor.lua
-- Version: v1.00 (2025-10-26)
-- Cancels ground right-click orders in Direct mode.
-- Scope: hero owned by the player in Direct mode only.
-- Safe for UI clicks: allows orders when mouse is over UI.
-- No percent characters anywhere.
--==================================================

do
    --------------------------------------------------
    -- TUNABLES
    --------------------------------------------------
    local SUPPRESS_SMART   = true    -- right click default
    local SUPPRESS_MOVE    = true    -- explicit Move
    local SUPPRESS_ATTACK  = true    -- right click attack on ground
    local SUPPRESS_PATROL  = true
    local SUPPRESS_STOP    = false   -- usually allow Stop
    local HERO_ONLY        = true    -- only cancel orders for the controlled hero
    local HONOR_UI_HOVER   = true    -- allow orders when pointer is over UI

    --------------------------------------------------
    -- HELPERS
    --------------------------------------------------
    local O_SMART  = OrderId("smart")
    local O_MOVE   = OrderId("move")
    local O_ATTACK = OrderId("attack")
    local O_PATROL = OrderId("patrol")
    local O_STOP   = OrderId("stop")

    local function PD() return rawget(_G, "PlayerData") end
    local function isDirect(pid)
        local P = PD(); return P and P.IsDirectControl and P.IsDirectControl(pid) or false
    end
    local function heroOf(pid)
        local P = PD()
        if P and P.Get then
            local t = P.Get(pid)
            if t and t.hero and GetUnitTypeId(t.hero) ~= 0 then return t.hero end
        end
        if _G.PlayerHero and PlayerHero[pid] and GetUnitTypeId(PlayerHero[pid]) ~= 0 then
            return PlayerHero[pid]
        end
        return nil
    end
    local function mouseOverUI()
        if not HONOR_UI_HOVER then return false end
        local fn = rawget(_G, "BlzGetMouseFocusFrame")
        if type(fn) == "function" then return fn() ~= nil end
        return false
    end
    local function isOurHero(u)
        if not HERO_ONLY then return true end
        local owner = GetOwningPlayer(u)
        local pid   = GetPlayerId(owner)
        return u == heroOf(pid)
    end

    local function shouldCancel(order)
        if order == O_SMART  and SUPPRESS_SMART  then return true end
        if order == O_MOVE   and SUPPRESS_MOVE   then return true end
        if order == O_ATTACK and SUPPRESS_ATTACK then return true end
        if order == O_PATROL and SUPPRESS_PATROL then return true end
        if order == O_STOP   and not SUPPRESS_STOP then return false end
        return false
    end

    local function cancel(u)
        -- Quick cancel without breaking animations
        IssueImmediateOrder(u, "stop")
        -- Safety nudge: pause for a frame to quash queued orders
        PauseUnit(u, true)
        PauseUnit(u, false)
    end

    --------------------------------------------------
    -- CORE: cancel point/target/instant orders while Direct is on
    --------------------------------------------------
    local function onIssuedAny()
        local u     = GetTriggerUnit()
        if u == nil or GetUnitTypeId(u) == 0 then return end

        local p     = GetOwningPlayer(u)
        local pid   = GetPlayerId(p)
        if not isDirect(pid) then return end
        if mouseOverUI() then return end
        if HERO_ONLY and not isOurHero(u) then return end

        local order = GetIssuedOrderId()
        if shouldCancel(order) then
            cancel(u)
        end
    end

    --------------------------------------------------
    -- WIRING
    --------------------------------------------------
    OnInit.final(function()
        -- Point orders (move-to, right-click ground)
        local t1 = CreateTrigger()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerUnitEvent(t1, Player(pid), EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER, nil)
        end
        TriggerAddAction(t1, onIssuedAny)

        -- Target orders (right-click attack unit)
        local t2 = CreateTrigger()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerUnitEvent(t2, Player(pid), EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
        end
        TriggerAddAction(t2, onIssuedAny)

        -- Immediate orders (stop, patrol)
        local t3 = CreateTrigger()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerUnitEvent(t3, Player(pid), EVENT_PLAYER_UNIT_ISSUED_ORDER, nil)
        end
        TriggerAddAction(t3, onIssuedAny)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("RightClickSuppressor")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
