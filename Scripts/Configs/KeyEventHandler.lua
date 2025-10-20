if Debug and Debug.beginFile then Debug.beginFile("KeyEventHandler.lua") end
--==================================================
-- KeyEventHandler.lua
-- Centralized key events with per-player debounce.
-- • L -> PlayerMenu.Toggle(pid)
-- • P -> CombatThreatHUD.Toggle(pid) (if present)
-- • Prints "L down" when L is pressed (debug)
-- • Chat fallback: -pm toggles PlayerMenu
--==================================================

do
    local lastPress = {}
    local debounce  = { [OSKEY_L] = 0.25, [OSKEY_P] = 0.25 }

    local function now()
        if os and os.clock then return os.clock() end
        return 0
    end

    local function okToFire(pid, key)
        lastPress[pid] = lastPress[pid] or {}
        local t = now()
        local lp = lastPress[pid][key] or 0
        if (t - lp) < (debounce[key] or 0.25) then return false end
        lastPress[pid][key] = t
        return true
    end

    local function onL(pid, isDown)
        if not isDown then return end  -- we act only on key down
        -- Debug ping so we know L is captured
        DisplayTextToPlayer(Player(pid), 0, 0, "L down")
        if not okToFire(pid, OSKEY_L) then return end

        if _G.PlayerMenu and PlayerMenu.Toggle then
            local ok, err = pcall(PlayerMenu.Toggle, pid)
            if not ok and err then
                DisplayTextToPlayer(Player(pid), 0, 0, "PlayerMenu error")
            end
        else
            DisplayTextToPlayer(Player(pid), 0, 0, "PlayerMenu not loaded")
        end
    end

    local function onP(pid, isDown)
        if not isDown then return end
        if not okToFire(pid, OSKEY_P) then return end
        if _G.CombatThreatHUD and CombatThreatHUD.Toggle then
            pcall(CombatThreatHUD.Toggle, pid)
        end
    end

    OnInit.final(function()
        -- Key events
        for pid = 0, bj_MAX_PLAYERS - 1 do
            local trig = CreateTrigger()
            -- Register both down and up; we'll check the state in the action
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_L, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_L, 0, false)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_P, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_P, 0, false)
            TriggerAddAction(trig, function()
                local p    = GetTriggerPlayer()
                local id   = GetPlayerId(p)
                local key  = BlzGetTriggerPlayerKey()
                local down = BlzGetTriggerPlayerIsKeyDown()
                if key == OSKEY_L then onL(id, down); return end
                if key == OSKEY_P then onP(id, down); return end
            end)
        end

        -- Chat fallback: -pm toggles PlayerMenu (helps if key events are blocked)
        local tpm = CreateTrigger()
        for i = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerChatEvent(tpm, Player(i), "-pm", true)
        end
        TriggerAddAction(tpm, function()
            local p   = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            if _G.PlayerMenu and PlayerMenu.Toggle then
                pcall(PlayerMenu.Toggle, pid)
            else
                DisplayTextToPlayer(p, 0, 0, "PlayerMenu not loaded")
            end
        end)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("KeyEventHandler")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
