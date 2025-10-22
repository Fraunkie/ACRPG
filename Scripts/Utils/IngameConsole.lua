--==================================================
-- IngameConsole.lua
-- See original .wct for full comments and implementation details
--==================================================

-- Remove the trigger registration from OnInit
OnInit.final(function()
    -- Remove these lines:
    local t = CreateTrigger()
    for i = 0, bj_MAX_PLAYER_SLOTS-1 do
        TriggerRegisterPlayerChatEvent(t, Player(i), ".", false)
    end
    TriggerAddAction(t, OnConsoleCommand)
    
    -- Keep any other initialization code
end)
