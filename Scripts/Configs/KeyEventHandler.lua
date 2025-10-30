if Debug and Debug.beginFile then Debug.beginFile("KeyEventHandler.lua") end
--==================================================
-- KeyEventHandler.lua  (MAIN)
-- Version: v1.17
-- UI focus gating so DirectControl/camera won't interfere while menus are open.
-- Context F:
--   • near teleporter crystal -> return to last hub
--   • near Yemma -> open YemmaHub
--   • else pick up nearby owned items
-- L opens PlayerMenu (sets uiFocus=TRUE).
-- ESC closes menus and clears uiFocus=FALSE.
-- Ability hotkeys + TAB targeting unchanged.
--==================================================

do
    -- Debug toggle at the top (set to true to enable debug output)
    local ENABLE_DEBUG = true

    -- Debug print function to display messages to the player
    local function debugPrint(msg, pid)
        if ENABLE_DEBUG then
            DisplayTextToPlayer(Player(pid), 0, 0, "[DEBUG] " .. tostring(msg))
        end
    end

    local lastPress = {}
    local debounce  = {
        [OSKEY_O]        = 0.20,
        [OSKEY_L]        = 0.25,
        [OSKEY_P]        = 0.25,
        [OSKEY_F]        = 0.25,
        [OSKEY_ESCAPE]   = 0.08,

        -- ability hotkeys + tab
        [OSKEY_Q]        = 0.10,
        [OSKEY_E]        = 0.10,
        [OSKEY_R]        = 0.10,
        [OSKEY_T]        = 0.10,
        [OSKEY_Z]        = 0.10,
        [OSKEY_X]        = 0.10,
        [OSKEY_C]        = 0.10,
        [OSKEY_V]        = 0.10,
        [OSKEY_G]        = 0.10,
        [OSKEY_TAB]      = 0.12,
    }

    -- Teleporter / hubs
    local TELEPORTER_UNIT_ID = FourCC("h0CH")
    local TELEPORTER_RANGE   = 300.0
    local DEFAULT_HUB_R      = 300.0
    local PICKUP_RANGE       = 250.0

    local function now() return (os and os.clock and os.clock()) or 0 end
    local function okToFire(pid, key)
        lastPress[pid] = lastPress[pid] or {}
        local t, lp = now(), (lastPress[pid][key] or 0)
        if (t - lp) < (debounce[key] or 0.25) then return false end
        lastPress[pid][key] = t
        return true
    end

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    

    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function heroOf(pid)
        if _G.PlayerData and PlayerData[pid] and validUnit(PlayerData[pid].hero) then
            return PlayerData[pid].hero
        end
        if _G.PlayerHero and validUnit(PlayerHero[pid]) then
            return PlayerHero[pid]
        end
        return nil
    end

    local function ensureControl(pid)
        local pd = _G.PlayerData and PlayerData[pid]
        if not pd then return nil end
        pd.control = pd.control or {
            direct=false, holdW=false, holdA=false, holdS=false, holdD=false,
            rmb=false, lmb=false, yaw=nil, pitch=nil, dist=nil, uiFocus=false,
        }
        return pd.control, pd
    end

    local function setUiFocus(pid, flag)
        local c = ensureControl(pid); if not c then return end
        c.uiFocus = (flag == true)
        if _G.ProcBus and ProcBus.Emit then
            ProcBus.Emit("UiFocusChanged", { pid = pid, focused = c.uiFocus })
        end
    end

    local function dist2(ax, ay, bx, by)
        local dx = ax - bx
        local dy = ay - by
        return dx*dx + dy*dy
    end

    local function closeAll(pid)
        if _G.YemmaHub and YemmaHub.Close then pcall(YemmaHub.Close, pid) end
        if _G.YemmaTravel and YemmaTravel.Close then pcall(YemmaTravel.Close, pid) end
        if _G.PlayerMenu and PlayerMenu.Hide then pcall(PlayerMenu.Hide, pid) end
        if _G.CombatThreatHUD and CombatThreatHUD.Hide then pcall(CombatThreatHUD.Hide, pid) end
        if _G.PlayerMenu_SpellbookModule and PlayerMenu_SpellbookModule.Close then
            pcall(PlayerMenu_SpellbookModule.Close, pid)
        end
        setUiFocus(pid, false)
    end
    --------------------------------------------------
    -- Key actions
    --------------------------------------------------

    -- Context F: Check if near Yemma's desk and open YemmaHub
    local function onF(pid, isDown)
        if not isDown or not okToFire(pid, OSKEY_F) then return end

        -- Debug: Check if the `F` key press is being detected
        debugPrint("F key pressed by player " .. tostring(pid), pid)

        -- Check if near Yemma's Desk
        local hero = heroOf(pid)
        if not validUnit(hero) then return end
        local ux, uy = GetUnitX(hero), GetUnitY(hero)

        -- Yemma's Desk Hub coordinates
        local yemmaCoords = { x = 28853.2, y = 28777.6 } -- Coordinates for Yemma's Desk

        -- Check if within range of Yemma's Desk
        local distToYemma = dist2(ux, uy, yemmaCoords.x, yemmaCoords.y)
        local rangeToYemma = DEFAULT_HUB_R * DEFAULT_HUB_R

        if distToYemma <= rangeToYemma then
            debugPrint("Player " .. tostring(pid) .. " is near Yemma's Desk, opening YemmaHub", pid)

            -- Open YemmaHub
            if _G.YemmaHub and YemmaHub.Open then
                pcall(YemmaHub.Open, pid)
                 -- Set focus so the UI is interactive
                return
            else
                debugPrint("Failed to open YemmaHub for player " .. tostring(pid), pid)  -- Error if YemmaHub fails to open
            end
        end

        -- 2) Otherwise, try picking up nearby owned items (disabled here)
        -- tryPickupNearby(pid) -- Removed as per your request
    end

    -- L key: Toggle Player Menu
    local function onL(pid, isDown)
        if not isDown or not okToFire(pid, OSKEY_L) then return end
        if _G.PlayerMenu and PlayerMenu.Toggle then
            pcall(PlayerMenu.Toggle, pid)
            setUiFocus(pid, true)
        end
    end

    -- P key: Toggle Combat Threat HUD
    local function onP(pid, isDown)
        if not isDown or not okToFire(pid, OSKEY_P) then return end
        if _G.CombatThreatHUD and CombatThreatHUD.Toggle then
            pcall(CombatThreatHUD.Toggle, pid)
        end
    end

    -- O key: Toggle Direct Control
    local function onO(pid, isDown)
        if not isDown or not okToFire(pid, OSKEY_O) then return end
        local c = ensureControl(pid); if not c then return end
        c.direct = not c.direct
        if _G.ProcBus and ProcBus.Emit then
            ProcBus.Emit("DirectControlToggled", { pid = pid, enabled = c.direct })
        end
    end

    -- Context ESC: Close all menus
    local function onEsc(pid, isDown)
        if not isDown or not okToFire(pid, OSKEY_ESCAPE) then return end
        closeAll(pid)
    end

    -- Tab key: Target Cycle
    local function onTab(pid, isDown)
        if not isDown or not okToFire(pid, OSKEY_TAB) then return end
        if _G.TargetingSystem and TargetingSystem.Cycle then
            TargetingSystem.Cycle(pid)
        elseif _G.ProcBus and ProcBus.Emit then
            ProcBus.Emit("RequestTargetCycle", { pid = pid })
        end
    end
    
        local function onSlot(pid, isDown, slot)
        if not isDown then return end
        if CustomSpellBar and CustomSpellBar.ActivateSlot then
            CustomSpellBar.ActivateSlot(pid, slot)
        end
    end
    --------------------------------------------------
    -- Wiring + bus hooks
    --------------------------------------------------
    local function wireBusFocus()
        local PB = rawget(_G, "ProcBus")
        if not PB or not PB.On then return end
        PB.On("MenuOpened",  function(e) if e and type(e.pid)=="number" then setUiFocus(e.pid, true)  end end)
        PB.On("MenuClosed",  function(e) if e and type(e.pid)=="number" then setUiFocus(e.pid, false) end end)
        PB.On("YemmaHubOpened",   function(e) if e and e.pid then setUiFocus(e.pid, true)  end end)
        PB.On("YemmaHubClosed",   function(e) if e and e.pid then setUiFocus(e.pid, false) end end)
        PB.On("PlayerMenuOpened", function(e) if e and e.pid then setUiFocus(e.pid, true)  end end)
        PB.On("PlayerMenuClosed", function(e) if e and e.pid then setUiFocus(e.pid, false) end end)
    end

    OnInit.final(function()
        wireBusFocus()

        for pid = 0, bj_MAX_PLAYERS - 1 do
            local trig = CreateTrigger()

            -- Keys
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_O,      0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_O,      0, false)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_L,      0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_L,      0, false)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_P,      0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_P,      0, false)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_F,      0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_F,      0, false)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_ESCAPE, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_ESCAPE, 0, false)

            -- Ability hotkeys
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_Q, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_E, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_R, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_T, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_Z, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_X, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_C, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_V, 0, true)

            -- TAB
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_TAB, 0, true)

            TriggerAddAction(trig, function()
                local p    = GetTriggerPlayer()
                local id   = GetPlayerId(p)
                local key  = BlzGetTriggerPlayerKey()
                local down = BlzGetTriggerPlayerIsKeyDown()

                if key == OSKEY_O      then onO(id, down);   return end
                if key == OSKEY_L      then onL(id, down);   return end
                if key == OSKEY_P      then onP(id, down);   return end
                if key == OSKEY_F      then onF(id, down);   return end
                if key == OSKEY_ESCAPE then onEsc(id, down); return end

                if key == OSKEY_Q and okToFire(id, OSKEY_Q) then onSlot(id, down, 1); return end
                if key == OSKEY_E and okToFire(id, OSKEY_E) then onSlot(id, down, 2); return end
                if key == OSKEY_R and okToFire(id, OSKEY_R) then onSlot(id, down, 3); return end
                if key == OSKEY_T and okToFire(id, OSKEY_T) then onSlot(id, down, 4); return end
                if key == OSKEY_Z and okToFire(id, OSKEY_Z) then onSlot(id, down, 5); return end
                if key == OSKEY_X and okToFire(id, OSKEY_X) then onSlot(id, down, 6); return end
                if key == OSKEY_C and okToFire(id, OSKEY_C) then onSlot(id, down, 7); return end
                if key == OSKEY_V and okToFire(id, OSKEY_V) then onSlot(id, down, 8); return end

                if key == OSKEY_TAB then onTab(id, down); return end
            end)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("KeyEventHandler")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
