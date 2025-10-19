if Debug and Debug.beginFile then Debug.beginFile("KeyEventHandler.lua") end

-- Centralized Key Event Management
local keyState = {}  -- Table to track debounce states

-- Config (for each custom key)
local keyConfig = {
    [OSKEY_L] = { debounce = 0.25, isPressed = false, action = "toggleMenu" },  -- 'L' toggles Player Menu
    -- Add more keys here if needed (e.g., OSKEY_P for other actions)
}

-- Function to handle key events (with debounce)
local function HandleKeyEvent(pid, key)
    local keyInfo = keyConfig[key]
    if not keyInfo or keyInfo.isPressed then return end  -- If no action or key is still in cooldown, do nothing

    keyInfo.isPressed = true  -- Mark key as pressed
    DisplayTextToPlayer(Player(pid), 0, 0, "[Debug] Key Pressed: " .. key)  -- Debug output for key press

    -- Perform the action based on the key pressed
    if keyInfo.action == "toggleMenu" then
        -- Call Player Menu toggle function
        PlayerMenu.Toggle(pid)
    end

    -- Debounce: Set a timer to reset the key state after debounce time
    local t = CreateTimer()
    TimerStart(t, keyInfo.debounce, false, function()
        keyInfo.isPressed = false  -- Reset debounce
        DestroyTimer(t)
    end)
end

-- Register key events for all players
OnInit.final(function()
    -- Register player key events
    for pid = 0, bj_MAX_PLAYERS - 1 do
        local trig = CreateTrigger()
        for key, _ in pairs(keyConfig) do
            -- Register OS key event for each key
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), key, 0, true)
        end

        TriggerAddAction(trig, function()
            local p = GetTriggerPlayer()
            local id = GetPlayerId(p)
            -- We check which key was pressed using the `key` config
            local pressedKey = GetTriggerPlayer()  -- Check the key press and validate it

            HandleKeyEvent(id, pressedKey)  -- Call the handler
        end)
    end
end)

if Debug and Debug.endFile then Debug.endFile() end
