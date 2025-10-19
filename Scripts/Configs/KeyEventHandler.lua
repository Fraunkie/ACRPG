if Debug and Debug.beginFile then Debug.beginFile("KeyEventHandler.lua") end
--==================================================
-- KeyEventHandler.lua
-- Centralized key events with per-player debounce.
-- • L toggles PlayerMenu
-- • P toggles CombatThreatHUD
-- • No percent symbols anywhere
--==================================================

do
    -- per player -> per key -> last time pressed
    local lastPress = {}      -- lastPress[pid][key] = os.clock value
    local debounce  = {       -- seconds per key
        [OSKEY_L] = 0.25,
        [OSKEY_P] = 0.25,
    }

    -- helpers
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

    local function handle(pid, key)
        if not okToFire(pid, key) then return end

        -- L -> PlayerMenu
        if key == OSKEY_L then
            if _G.PlayerMenu and PlayerMenu.Toggle then
                pcall(PlayerMenu.Toggle, pid)
            end
            return
        end

        -- P -> CombatThreatHUD
        if key == OSKEY_P then
            if _G.CombatThreatHUD and CombatThreatHUD.Toggle then
                pcall(CombatThreatHUD.Toggle, pid)
            end
            return
        end
    end

    OnInit.final(function()
        -- one trigger per player, register both keys
        for pid = 0, bj_MAX_PLAYERS - 1 do
            local trig = CreateTrigger()
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_L, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_P, 0, true)
            TriggerAddAction(trig, function()
                local p   = GetTriggerPlayer()
                local id  = GetPlayerId(p)
                local key = BlzGetTriggerPlayerKey()
                handle(id, key)
            end)
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("KeyEventHandler")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
