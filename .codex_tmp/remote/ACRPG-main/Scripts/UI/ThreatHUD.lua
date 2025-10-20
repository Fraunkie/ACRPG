if Debug and Debug.beginFile then Debug.beginFile("CombatThreatHUD.lua") end
--==================================================
-- CombatThreatHUD.lua
-- Sticky HUD controller with periodic + event refresh.
-- • Toggled externally (KeyEventHandler binds P)
-- • Stays visible once toggled on (per-player)
-- • Refresh on CREEP_SPAWN/DEATH and OnDealtDamage
-- • Periodic refresh fallback (0.5s)
--==================================================

do
    CombatThreatHUD = CombatThreatHUD or {}
    _G.CombatThreatHUD = CombatThreatHUD

    -- Layout knobs (percent-of-screen; adjust as needed)
    CombatThreatHUD.POS = CombatThreatHUD.POS or { x = 0.03, y = 0.78 }
    CombatThreatHUD.W   = CombatThreatHUD.W   or 0.22
    CombatThreatHUD.H   = CombatThreatHUD.H   or 0.18

    -- Sticky visibility + build flags
    CombatThreatHUD.visible     = CombatThreatHUD.visible     or {} -- [pid]=bool
    CombatThreatHUD._built      = CombatThreatHUD._built      or {} -- [pid]=bool
    CombatThreatHUD._needRedraw = CombatThreatHUD._needRedraw or {} -- [pid]=bool

    local function isHumanPid(pid)
        if pid == nil or pid < 0 or pid >= bj_MAX_PLAYERS then return false end
        return GetPlayerController(Player(pid)) == MAP_CONTROL_USER
    end

    local function ensureBuilt(pid)
        if not isHumanPid(pid) then return end
        if not CombatThreatHUD._built[pid] then
            if CombatThreatHUD.Build then CombatThreatHUD.Build(pid) end
            if CombatThreatHUD.Reanchor then
                CombatThreatHUD.Reanchor(pid, CombatThreatHUD.POS, CombatThreatHUD.W, CombatThreatHUD.H)
            end
            CombatThreatHUD._built[pid] = true
        end
    end

    function CombatThreatHUD.Show(pid)
        if not isHumanPid(pid) then return end
        CombatThreatHUD.visible[pid] = true
        ensureBuilt(pid)
        if CombatThreatHUD.Redraw then CombatThreatHUD.Redraw(pid) end
    end

    function CombatThreatHUD.Hide(pid)
        if not isHumanPid(pid) then return end
        CombatThreatHUD.visible[pid] = false
        if CombatThreatHUD._Hide then CombatThreatHUD._Hide(pid) end -- optional impl
    end

    function CombatThreatHUD.Toggle(pid)
        if not isHumanPid(pid) then return end
        local on = not CombatThreatHUD.visible[pid]
        if on then CombatThreatHUD.Show(pid) else CombatThreatHUD.Hide(pid) end
    end

    function CombatThreatHUD.Refresh(pid, force)
        if not isHumanPid(pid) or not CombatThreatHUD.visible[pid] then return end
        ensureBuilt(pid)
        if CombatThreatHUD.Reanchor then
            CombatThreatHUD.Reanchor(pid, CombatThreatHUD.POS, CombatThreatHUD.W, CombatThreatHUD.H)
        end
        if force or CombatThreatHUD._needRedraw[pid] then
            CombatThreatHUD._needRedraw[pid] = nil
            if CombatThreatHUD.Redraw then CombatThreatHUD.Redraw(pid) end
        end
    end

    local function refreshAll(force)
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if isHumanPid(pid) then CombatThreatHUD.Refresh(pid, force) end
        end
    end

    OnInit.final(function()
        -- Periodic fallback refresh (keeps HUD alive if no events fire)
        local tick = CreateTimer()
        TimerStart(tick, 0.50, true, function() refreshAll(false) end)

        -- Event-driven refresh
        if ProcBus then
            local mark = function(pid)
                if isHumanPid(pid) and CombatThreatHUD.visible[pid] then
                    CombatThreatHUD._needRedraw[pid] = true
                end
            end
            local dmgHandler = function(e) if e and e.pid ~= nil then mark(e.pid) end end

            if ProcBus.Subscribe then
                ProcBus.Subscribe("OnDealtDamage", dmgHandler)
                ProcBus.Subscribe("CREEP_SPAWN", function() refreshAll(true) end)
                ProcBus.Subscribe("CREEP_DEATH", function() refreshAll(true) end)
            elseif ProcBus.On then
                ProcBus.On("OnDealtDamage", dmgHandler)
                ProcBus.On("CREEP_SPAWN", function() refreshAll(true) end)
                ProcBus.On("CREEP_DEATH", function() refreshAll(true) end)
            end
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CombatThreatHUD")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
