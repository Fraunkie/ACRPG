if Debug and Debug.beginFile then Debug.beginFile("KeyEventHandler.lua") end
--==================================================
-- KeyEventHandler.lua  (MAIN)
-- Version: v1.17
-- UI focus gating so DirectControl/camera won't interfere while menus are open.
-- Context F:
--   • near teleporter crystal -> return to last hub
--   • else near hub -> open YemmaHub (sets uiFocus=TRUE)
--   • else pick up nearby owned items
-- L opens PlayerMenu (sets uiFocus=TRUE).
-- ESC closes menus and clears uiFocus=FALSE.
-- Ability hotkeys + TAB targeting unchanged.
--==================================================

do
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

    -- Teleporter / hubs / pickup
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
        if _G.PLAYER_DATA and PLAYER_DATA[pid] and validUnit(PLAYER_DATA[pid].hero) then
            return PLAYER_DATA[pid].hero
        end
        if _G.PlayerHero and validUnit(PlayerHero[pid]) then
            return PlayerHero[pid]
        end
        return nil
    end

    local function ensureControl(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]
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

    local function listHubs()
        local GB = GameBalance or {}
        local hubs = {}
        if GB.NODE_COORDS then
            local ids = { "YEMMA", "KAMI_LOOKOUT", }
            for i = 1, #ids do
                local id  = ids[i]
                local xyz = GB.NODE_COORDS[id]
                if xyz and xyz.x and xyz.y then
                    hubs[#hubs+1] = { id = id, x = xyz.x, y = xyz.y, r = (GB.YEMMA_PROMPT_RADIUS or DEFAULT_HUB_R) }
                end
            end
        end
        if #hubs == 0 then
            local HC = (GameBalance and GameBalance.HUB_COORDS) or {}
            if HC.YEMMA and HC.YEMMA.x and HC.YEMMA.y then
                hubs[#hubs+1] = { id = "YEMMA", x = HC.YEMMA.x, y = HC.YEMMA.y, r = (GameBalance.YEMMA_PROMPT_RADIUS or DEFAULT_HUB_R) }
            end
        end
        return hubs
    end

    local function nearestHub(pid)
        local hubs = listHubs()
        if #hubs == 0 then return nil end
        local u = heroOf(pid); if not validUnit(u) then return nil end
        local ux, uy = GetUnitX(u), GetUnitY(u)
        local best, bestd = nil, nil
        for i = 1, #hubs do
            local h = hubs[i]
            local d2 = dist2(ux, uy, h.x, h.y)
            if d2 <= (h.r*h.r) and (not bestd or d2 < bestd) then
                best, bestd = h, d2
            end
        end
        return best
    end

    local function nearTeleporter(pid)
        local u = heroOf(pid); if not validUnit(u) then return false end
        local ux, uy = GetUnitX(u), GetUnitY(u)
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, ux, uy, TELEPORTER_RANGE, nil)
        local found = false
        while true do
            local t = FirstOfGroup(g); if not t then break end
            GroupRemoveUnit(g, t)
            if validUnit(t) and GetUnitTypeId(t) == TELEPORTER_UNIT_ID then
                found = true; break
            end
        end
        DestroyGroup(g)
        return found
    end

    local function tryReturnToHub(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid] or {}
        local dest = pd and pd.lastHubNode
        if not dest or dest == "" then
            local ids = (GameBalance and GameBalance.TELEPORT_NODE_IDS) or {}
            dest = ids.KAMI_LOOKOUT or "KAMI_LOOKOUT"
        end
        if _G.TeleportSystem and TeleportSystem.TeleportToNode then
            TeleportSystem.Unlock(pid, dest)
            TeleportSystem.TeleportToNode(pid, dest, { reason = "key_return", setHub = true })
            return true
        end
        return false
    end

    local function tryPickupNearby(pid)
        local u = heroOf(pid); if not validUnit(u) then return false end
        local ux, uy = GetUnitX(u), GetUnitY(u)
        local r = Rect(ux - PICKUP_RANGE, uy - PICKUP_RANGE, ux + PICKUP_RANGE, uy + PICKUP_RANGE)
        local picked = false
        EnumItemsInRectBJ(r, function()
            local it = GetEnumItem()
            if it and GetItemTypeId(it) ~= 0 then
                local ownerOk = true
                if GetItemPlayer then
                    local ip = GetItemPlayer(it)
                    if ip ~= nil and ip ~= Player(pid) then ownerOk = false end
                end
                if ownerOk then
                    if UnitAddItem(u, it) then
                        picked = true
                    else
                        -- Lua positional args only; WC3 expects (unit, order, target)
                        IssueTargetOrder(u, "smart", it)
                    end
                end
            end
        end)
        RemoveRect(r)
        return picked
    end

    --------------------------------------------------
    -- Close-All safely (no destruction)
    --------------------------------------------------
    local function closeAll(pid)
        if _G.YemmaHub and YemmaHub.Close then pcall(YemmaHub.Close, pid) end
        if _G.TeleportHub and TeleportHub.Hide then pcall(TeleportHub.Hide, pid) end
        if _G.PlayerMenu and PlayerMenu.Hide then pcall(PlayerMenu.Hide, pid) end
        if _G.CombatThreatHUD and CombatThreatHUD.Hide then pcall(CombatThreatHUD.Hide, pid) end
        setUiFocus(pid, false)
    end

    --------------------------------------------------
    -- Key actions
    --------------------------------------------------
    local function onO(pid, isDown)
        if not isDown or not okToFire(pid, OSKEY_O) then return end
        local c = ensureControl(pid); if not c then return end
        c.direct = not c.direct
        if _G.ProcBus and ProcBus.Emit then
            ProcBus.Emit("DirectControlToggled", { pid = pid, enabled = c.direct })
        end
    end

    local function onL(pid, isDown)
        if not isDown or not okToFire(pid, OSKEY_L) then return end
        if _G.PlayerMenu and PlayerMenu.Toggle then
            pcall(PlayerMenu.Toggle, pid)
            setUiFocus(pid, true)
        end
    end

    local function onP(pid, isDown)
        if not isDown or not okToFire(pid, OSKEY_P) then return end
        if _G.CombatThreatHUD and CombatThreatHUD.Toggle then
            pcall(CombatThreatHUD.Toggle, pid)
        end
    end

    -- Context F: teleporter crystal > hub menu > pickup items
    -- Context F: Check if near Yemma's desk and open YemmaHub
    local function onF(pid, isDown)
        if not isDown or not okToFire(pid, OSKEY_F) then return end

        -- Debug: Check if the `F` key press is being detected

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

            -- Open YemmaHub
            if _G.YemmaHub and YemmaHub.Open then
                pcall(YemmaHub.Open, pid)
                 -- Set focus so the UI is interactive
                return
            else
            end
        end

        -- 2) Otherwise, try picking up nearby owned items (disabled here)
        -- tryPickupNearby(pid) -- Removed as per your request
    end

    local function onEsc(pid, isDown)
        if not isDown or not okToFire(pid, OSKEY_ESCAPE) then return end
        closeAll(pid)
    end

    local function onSlot(pid, isDown, slot)
        if not isDown then return end
        if CustomSpellBar and CustomSpellBar.ActivateSlot then
            CustomSpellBar.ActivateSlot(pid, slot)
        end
    end

    local function onTab(pid, isDown)
        if not isDown or not okToFire(pid, OSKEY_TAB) then return end
        if _G.TargetingSystem and TargetingSystem.Cycle then
            TargetingSystem.Cycle(pid)
        elseif _G.ProcBus and ProcBus.Emit then
            ProcBus.Emit("RequestTargetCycle", { pid = pid })
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
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_G, 0, true)

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
                if key == OSKEY_G and okToFire(id, OSKEY_G) then onSlot(id, down, 9); return end

                if key == OSKEY_TAB then onTab(id, down); return end
            end)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("KeyEventHandler")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
