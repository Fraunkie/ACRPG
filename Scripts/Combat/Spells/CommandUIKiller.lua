if Debug and Debug.beginFile then Debug.beginFile("CommandUIKiller.lua") end
--==================================================
-- CommandUIKiller.lua
-- Hides native command card & inventory buttons safely (no crashes),
-- moves them to a hidden "sink" parent, disables tooltips,
-- and re-applies after selection changes so cooldown swirls never show.
--==================================================

do
    CommandUIKiller = CommandUIKiller or {}
    _G.CommandUIKiller = CommandUIKiller

    -- tiny off-screen frame we re-parent unwanted UI into
    local sink = nil

    local function ensureSink()
        if sink then return sink end
        local ui = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        sink = BlzCreateFrameByType("FRAME", "CmdSink", ui, "", 0)
        BlzFrameSetAbsPoint(sink, FRAMEPOINT_CENTER, 1.5, -1.5) -- way off-screen
        BlzFrameSetSize(sink, 0.0001, 0.0001)
        BlzFrameSetVisible(sink, false)
        return sink
    end

    local function killFrame(f)
        if not f then return end
        local s = ensureSink()
        -- make it inert, invisible, and out of layout
        BlzFrameSetEnable(f, false)
        BlzFrameSetVisible(f, false)
        BlzFrameClearAllPoints(f)
        BlzFrameSetParent(f, s)
        BlzFrameSetSize(f, 0.0001, 0.0001)
    end

    -- Some frames respawn or re-layout on selection; we neutralize both “by name”
    -- (stable in 1.32+) and origin-frame fallbacks just in case.
    local function hideCommandCardOnce()
        -- Command buttons (0..11)
        for i = 0, 11 do
            killFrame(BlzGetFrameByName("CommandButton_"..tostring(i), 0))
            killFrame(BlzGetOriginFrame(ORIGIN_FRAME_COMMAND_BUTTON, i))
        end

        -- Inventory buttons (0..5)
        for i = 0, 5 do
            killFrame(BlzGetFrameByName("InventoryButton_"..tostring(i), 0))
            killFrame(BlzGetOriginFrame(ORIGIN_FRAME_ITEM_BUTTON, i))
        end

        -- Built-in tooltips / unit messages that can pop when clicking items
        killFrame(BlzGetOriginFrame(ORIGIN_FRAME_TOOLTIP, 0))
        killFrame(BlzGetOriginFrame(ORIGIN_FRAME_UBERTOOLTIP, 0))
        killFrame(BlzGetOriginFrame(ORIGIN_FRAME_UNIT_MSG, 0))   -- bottom-center messages
        killFrame(BlzGetOriginFrame(ORIGIN_FRAME_TOP_MSG, 0))
    end

    -- Re-apply on selection changes (these frames reappear on every selection)
    local function hookSelectionWatcher()
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_SELECTED, nil)
        end
        TriggerAddAction(t, function()
            if GetLocalPlayer() == GetTriggerPlayer() then
                -- tiny delay so Blizzard finishes recreating the frames first
                TimerStart(CreateTimer(), 0.00, false, function()
                    hideCommandCardOnce()
                    DestroyTimer(GetExpiredTimer())
                end)
            end
        end)
    end

    -- Public: call once per player after your Bootflow UI is up
    function CommandUIKiller.Apply(pid)
        if GetLocalPlayer() ~= Player(pid) then return end
        ensureSink()
        hideCommandCardOnce()
    end

    OnInit.final(function()
        -- keep them dead even after selection changes
        hookSelectionWatcher()
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
