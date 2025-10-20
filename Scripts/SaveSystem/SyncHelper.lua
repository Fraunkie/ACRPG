if Debug and Debug.beginFile then Debug.beginFile("SyncHelper.lua") end
--==================================================
-- SyncHelper.lua
-- Minimal sync helpers for sending strings to peers.
--==================================================

if not SyncHelper then SyncHelper = {} end
_G.SyncHelper = SyncHelper

do
    local PREFIX = "ACSYNC"
    local trig = CreateTrigger()

    function SyncHelper.Send(s)
        return BlzSendSyncData(PREFIX, s or "")
    end

    function SyncHelper.On(fn)
        return TriggerAddAction(trig, fn)
    end

    function SyncHelper.Off(act)
        TriggerRemoveAction(trig, act)
    end

    OnInit.final(function()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            BlzTriggerRegisterPlayerSyncEvent(trig, Player(i), PREFIX, false)
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SyncHelper")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
