if Debug and Debug.beginFile then Debug.beginFile("KeyEventHandler.lua") end
--==================================================
-- KeyEventHandler.lua
-- Centralized key events with per-player debounce.
-- • L -> PlayerMenu.Toggle(pid)
-- • P -> CombatThreatHUD.Toggle(pid) (if present)
-- • F -> Open YemmaHub ONLY if near a configured hub (no spawn fallback)
-- • ESC -> Close all menus safely
--==================================================

do
    local lastPress = {}
    local debounce  = {
        [OSKEY_L]        = 0.25,
        [OSKEY_P]        = 0.25,
        [OSKEY_F]        = 0.25,
        [OSKEY_ESCAPE]   = 0.08,
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

    local function dist2(ax, ay, bx, by) local dx=ax-bx; local dy=ay-by; return dx*dx+dy*dy end

    -- Build the set of real hubs we allow to open from (NO SPAWN FALLBACK)
    local function listHubs()
        local GB = GameBalance or {}
        local hubs = {}

        -- Prefer canonical node coords if present
        if GB.NODE_COORDS then
            -- Common hubs we know about
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
        -- Only hide/close; DO NOT destroy frames here.
        if _G.YemmaHub and YemmaHub.Close then pcall(YemmaHub.Close, pid) end
        if _G.TeleportHub and TeleportHub.Hide then pcall(TeleportHub.Hide, pid) end
        if _G.PlayerMenu and PlayerMenu.Hide then pcall(PlayerMenu.Hide, pid) end
        if _G.CombatThreatHUD and CombatThreatHUD.Hide then pcall(CombatThreatHUD.Hide, pid) end
        -- Add more modules' Close/Hide calls here as needed.
    end

    --------------------------------------------------
    -- Key actions
    --------------------------------------------------
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
        if not hub then
            -- silently ignore if not near a real hub
            return
        end
        -- Open hub and land on HOME (not Tasks)
        if _G.YemmaHub and YemmaHub.Open then
            pcall(YemmaHub.Open, pid)
            if _G.YemmaHub.ShowHome then
                pcall(YemmaHub.ShowHome, pid)
            end
        end
    end

    local function onEsc(pid, isDown)
        -- The game fires ESC "down" events; avoid double handling with debounce.
        if not isDown then return end
        if not okToFire(pid, OSKEY_ESCAPE) then return end
        closeAll(pid)
    end

    --------------------------------------------------
    -- Wiring
    --------------------------------------------------
    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            local trig = CreateTrigger()
            -- Register DOWN and UP; we gate on down in handlers
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_L,      0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_L,      0, false)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_P,      0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_P,      0, false)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_F,      0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_F,      0, false)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_ESCAPE, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_ESCAPE, 0, false)

            TriggerAddAction(trig, function()
                local p    = GetTriggerPlayer()
                local id   = GetPlayerId(p)
                local key  = BlzGetTriggerPlayerKey()
                local down = BlzGetTriggerPlayerIsKeyDown()

                if key == OSKEY_L      then onL(id, down);   return end
                if key == OSKEY_P      then onP(id, down);   return end
                if key == OSKEY_F      then onF(id, down);   return end
                if key == OSKEY_ESCAPE then onEsc(id, down); return end
            end)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("KeyEventHandler")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
