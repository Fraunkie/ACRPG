if Debug and Debug.beginFile then Debug.beginFile("KeyEventHandler.lua") end
--==================================================
-- KeyEventHandler.lua  (MAIN)
-- Version: v1.13 (adds hotkeys for CustomSpellBar + Tab targeting)
-- Centralized key events with per-player debounce.
-- Always allow menus (L / P / F) even in DirectControl.
-- Keys:
--   O -> Toggle DirectControl (over-shoulder mode)
--   L -> PlayerMenu.Toggle(pid)
--   P -> CombatThreatHUD.Toggle(pid)
--   F -> Open YemmaHub ONLY if near a configured hub
--   ESC -> Close all menus safely
--   NEW HOTKEYS (ability bar):
--     Q(1), E(2), R(3), T(4), Z(5), X(6), C(7), V(8), G(9)  -- slot 10 currently unbound
--   NEW:
--     TAB -> TargetingSystem.Cycle (or ProcBus RequestTargetCycle)
--==================================================

do
    local lastPress = {}
    local debounce  = {
        [OSKEY_O]        = 0.20,
        [OSKEY_L]        = 0.25,
        [OSKEY_P]        = 0.25,
        [OSKEY_F]        = 0.25,
        [OSKEY_ESCAPE]   = 0.08,

        -- NEW: ability hotkeys + tab
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

    local function now()
        if os and os.clock then return os.clock() end
        return 0
    end

    local function okToFire(pid, key)
        lastPress[pid] = lastPress[pid] or {}
        local t  = now()
        local lp = lastPress[pid][key] or 0
        if (t - lp) < (debounce[key] or 0.25) then return false end
        lastPress[pid][key] = t
        return true
    end

    --------------------------------------------------
    -- Small helpers
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
            rmb=false, lmb=false, yaw=nil, pitch=nil, dist=nil,
        }
        return pd.control, pd
    end

    local function dist2(ax, ay, bx, by) local dx=ax-bx; local dy=ay-by; return dx*dx+dy*dy end

    -- Build the set of real hubs we allow to open from (NO SPAWN FALLBACK)
    local function listHubs()
        local GB = GameBalance or {}
        local hubs = {}

        -- Prefer canonical node coords if present
        if GB.NODE_COORDS then
            local ids = { "YEMMA", "KAMI_LOOKOUT", "HFIL" }
            for i=1,#ids do
                local id = ids[i]
                local xyz = GB.NODE_COORDS[id]
                if xyz and xyz.x and xyz.y then
                    hubs[#hubs+1] = { id = id, x = xyz.x, y = xyz.y, r = (GB.YEMMA_PROMPT_RADIUS or 300.0) }
                end
            end
        end

        -- Fallback to HUB_COORDS for Yemma if provided
        if #hubs == 0 then
            local HC = (GameBalance and GameBalance.HUB_COORDS) or {}
            if HC.YEMMA and HC.YEMMA.x and HC.YEMMA.y then
                hubs[#hubs+1] = { id = "YEMMA", x = HC.YEMMA.x, y = HC.YEMMA.y, r = (GameBalance.YEMMA_PROMPT_RADIUS or 300.0) }
            end
        end

        return hubs
    end

    local function nearestHub(pid)
        local hubs = listHubs()
        if #hubs == 0 then return nil end
        local u = heroOf(pid)
        if not validUnit(u) then return nil end
        local ux, uy = GetUnitX(u), GetUnitY(u)
        local best, bestd = nil, nil
        for i=1,#hubs do
            local h = hubs[i]
            local d2 = dist2(ux, uy, h.x, h.y)
            if d2 <= (h.r*h.r) and (not bestd or d2 < bestd) then
                best, bestd = h, d2
            end
        end
        return best
    end

    --------------------------------------------------
    -- Close-All safely (no destruction)
    --------------------------------------------------
    local function closeAll(pid)
        if _G.YemmaHub and YemmaHub.Close then pcall(YemmaHub.Close, pid) end
        if _G.TeleportHub and TeleportHub.Hide then pcall(TeleportHub.Hide, pid) end
        if _G.PlayerMenu and PlayerMenu.Hide then pcall(PlayerMenu.Hide, pid) end
        if _G.CombatThreatHUD and CombatThreatHUD.Hide then pcall(CombatThreatHUD.Hide, pid) end
    end

    --------------------------------------------------
    -- Key actions (menus always allowed)
    --------------------------------------------------
    local function onO(pid, isDown)
        if not isDown then return end
        if not okToFire(pid, OSKEY_O) then return end
        local c = ensureControl(pid)
        if not c then return end
        c = c
        c.direct = not c.direct
        if _G.ProcBus and ProcBus.Emit then
            ProcBus.Emit("DirectControlToggled", { pid = pid, enabled = c.direct })
        end
    end

    local function onL(pid, isDown)
        if not isDown then return end
        if not okToFire(pid, OSKEY_L) then return end
        if _G.PlayerMenu and PlayerMenu.Toggle then
            pcall(PlayerMenu.Toggle, pid)
        end
    end

    local function onP(pid, isDown)
        if not isDown then return end
        if not okToFire(pid, OSKEY_P) then return end
        if _G.CombatThreatHUD and CombatThreatHUD.Toggle then
            pcall(CombatThreatHUD.Toggle, pid)
        end
    end

    local function onF(pid, isDown)
        if not isDown then return end
        if not okToFire(pid, OSKEY_F) then return end
        local hub = nearestHub(pid)
        if not hub then return end
        if _G.YemmaHub and YemmaHub.Open then
            pcall(YemmaHub.Open, pid)
            if _G.YemmaHub.ShowHome then
                pcall(YemmaHub.ShowHome, pid)
            end
        end
    end

    local function onEsc(pid, isDown)
        if not isDown then return end
        if not okToFire(pid, OSKEY_ESCAPE) then return end
        closeAll(pid)
    end

    -- NEW: Ability hotkey handlers → call CustomSpellBar.ActivateSlot
    local function onSlot(pid, isDown, slot)
        if not isDown then return end
        -- small debounce per key handled in okToFire at call site
        if CustomSpellBar and CustomSpellBar.ActivateSlot then
            CustomSpellBar.ActivateSlot(pid, slot)
        end
    end

    -- NEW: Tab target cycle
    local function onTab(pid, isDown)
        if not isDown then return end
        if not okToFire(pid, OSKEY_TAB) then return end
        if _G.TargetingSystem and TargetingSystem.Cycle then
            TargetingSystem.Cycle(pid)
        elseif _G.ProcBus and ProcBus.Emit then
            ProcBus.Emit("RequestTargetCycle", { pid = pid })
        end
    end

    --------------------------------------------------
    -- Wiring
    --------------------------------------------------
    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            local trig = CreateTrigger()

            -- Existing keys
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

            -- NEW: ability hotkeys
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_Q, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_E, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_R, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_T, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_Z, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_X, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_C, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_V, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_G, 0, true)

            -- NEW: tab for targeting
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

                -- ability keys with per-key debounce checks
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
