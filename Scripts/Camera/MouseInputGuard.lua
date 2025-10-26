if Debug and Debug.beginFile then Debug.beginFile("MouseInputGuard.lua") end
--==================================================
-- MouseInputGuard.lua
-- Version: v1.32 (2025-10-26)
-- Prevents WC3 box/hover selection during DirectControl,
-- but KEEPS normal selection and right-click orders working.
-- • Disables PreSelect + DragSelect only
-- • Leaves Select enabled so you can interact/pick up items
-- • Client-local and per-player safe
-- • Optional debug prints (no percent symbols)
--==================================================

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local POLL_DT     = 0.03
    local DEBUG_LOG   = false   -- set true to see mask toggles and readiness prints

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local masked = {} -- [pid] = bool (whether we currently mask pre/drag select for pid)

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function isUser(pid)
        return GetPlayerController(Player(pid)) == MAP_CONTROL_USER
    end

    local function isDirect(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]
        local c  = pd and pd.control
        return c and c.direct == true
    end

    local function log(pid, msg)
        if not DEBUG_LOG then return end
        if GetLocalPlayer() == Player(pid) then
            DisplayTextToPlayer(Player(pid), 0, 0, "[MouseInputGuard] " .. tostring(msg))
        end
    end

    -- Apply or clear the selection mask for the local client of pid
    local function applyMaskLocal(pid, on)
        if GetLocalPlayer() ~= Player(pid) then return end

        if on then
            -- Mask only the things that cause WC3 selection to hijack control
            -- Keep EnableSelect(true) so right-click and item pickups still work.
            EnablePreSelect(false)
            EnableDragSelect(false)
            EnableSelect(true)
        else
            -- Restore everything
            EnablePreSelect(true)
            EnableDragSelect(true)
            EnableSelect(true)
        end
    end

    local function setMasked(pid, on)
        if masked[pid] == on then return end
        masked[pid] = on
        applyMaskLocal(pid, on)
        log(pid, on and "Mask ON (preselect off, drag off, select kept on)" or "Mask OFF (all selection restored)")
    end

    --------------------------------------------------
    -- Wiring
    --------------------------------------------------
    OnInit.final(function()
        -- Initialize cache
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            masked[pid] = false
        end

        -- Periodic check to mirror PlayerData.control.direct
        local t = CreateTimer()
        TimerStart(t, POLL_DT, true, function()
            for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
                if isUser(pid) then
                    setMasked(pid, isDirect(pid))
                elseif masked[pid] then
                    setMasked(pid, false)
                end
            end
        end)

        -- React immediately when other systems toggle direct control
        if _G.ProcBus and ProcBus.On then
            ProcBus.On("DirectControlToggled", function(e)
                if not e or type(e.pid) ~= "number" then return end
                local pid = e.pid
                if not isUser(pid) then return end
                setMasked(pid, e.enabled and true or false)
            end)
        end

        -- Ready message (local to each user)
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if isUser(pid) and DEBUG_LOG and GetLocalPlayer() == Player(pid) then
                DisplayTextToPlayer(Player(pid), 0, 0, "[MouseInputGuard] ready")
            end
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("MouseInputGuard")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
