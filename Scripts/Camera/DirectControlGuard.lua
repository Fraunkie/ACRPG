if Debug and Debug.beginFile then Debug.beginFile("DirectControlGuard.lua") end
--==================================================
-- DirectControlGuard.lua
-- Version: v1.0 (2025-10-23)
-- When PlayerData.control.direct is true:
--   • Hides command buttons for that player
--   • Cancels hero orders so W A S D hotkeys cannot issue game orders
-- WC3-safe. No percent symbols.
--==================================================

do
    local POLL_DT = 0.10

    -- cache state so we only toggle UI when it actually changes
    local uiShown = {} -- [pid] = true when command card currently shown

    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function heroOf(pid)
        if _G.PLAYER_DATA and PLAYER_DATA[pid] and validUnit(PLAYER_DATA[pid].hero) then
            return PLAYER_DATA[pid].hero
        end
        if _G.PlayerHero and validUnit(PlayerHero[pid]) then
            return PlayerHero[pid]
        end
        return nil
    end

    --------------------------------------------------
    -- Command card visibility helpers
    --------------------------------------------------
    local function setCommandButtonsVisible(pid, show)
        -- Command buttons are CommandButton_0 .. CommandButton_11
        -- We disable and hide them. Do this only for the local player.
        if GetLocalPlayer() ~= Player(pid) then return end
        for i = 0, 11 do
            local name = "CommandButton_" .. tostring(i)
            local f = BlzGetFrameByName(name, 0)
            if f then
                BlzFrameSetEnable(f, show)
                BlzFrameSetVisible(f, show)
            end
        end
        -- Also hide the minimap action buttons row if you wish later.
    end

    --------------------------------------------------
    -- Order blocker: stop any order to the hero while direct is on
    --------------------------------------------------
    local function onAnyOrder(pid)
        local u = GetTriggerUnit()
        local h = heroOf(pid)
        if not h or u ~= h then return end
        local pd = PLAYER_DATA[pid]
        local c = pd and pd.control
        if not c or not c.direct then return end
        -- Cancel the order to keep direct control pristine
        IssueImmediateOrder(u, "stop")
    end

    --------------------------------------------------
    -- Wiring
    --------------------------------------------------
    OnInit.final(function()
        -- register order blockers
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            uiShown[pid] = true

            local t1 = CreateTrigger()
            TriggerRegisterPlayerUnitEvent(t1, Player(pid), EVENT_PLAYER_UNIT_ISSUED_ORDER, nil)
            TriggerAddAction(t1, function() onAnyOrder(pid) end)

            local t2 = CreateTrigger()
            TriggerRegisterPlayerUnitEvent(t2, Player(pid), EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER, nil)
            TriggerAddAction(t2, function() onAnyOrder(pid) end)

            local t3 = CreateTrigger()
            TriggerRegisterPlayerUnitEvent(t3, Player(pid), EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
            TriggerAddAction(t3, function() onAnyOrder(pid) end)
        end

        -- periodic UI sync to PlayerData.control.direct
        local timer = CreateTimer()
        TimerStart(timer, POLL_DT, true, function()
            for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
                local pd = _G.PLAYER_DATA and PLAYER_DATA[pid] or nil
                local direct = (pd and pd.control and pd.control.direct) and true or false
                if direct and uiShown[pid] then
                    setCommandButtonsVisible(pid, false)
                    uiShown[pid] = false
                elseif (not direct) and (not uiShown[pid]) then
                    setCommandButtonsVisible(pid, true)
                    uiShown[pid] = true
                end
            end
        end)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("DirectControlGuard")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
