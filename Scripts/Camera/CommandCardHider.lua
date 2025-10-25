if Debug and Debug.beginFile then Debug.beginFile("CommandCardHider.lua") end
--==================================================
-- CommandCardHider.lua
-- Version: v1.0 (2025-10-23)
-- Hides the entire Command Card (Move/Attack/Stop/Patrol/Hold/etc.) while Direct Control is ON.
-- Restores it when Direct Control is OFF.
-- • Per-player, local-only visibility changes (GetLocalPlayer safe).
-- • No dependencies beyond PlayerData.lua (ProcBus optional).
--==================================================

if not CommandCardHider then CommandCardHider = {} end
_G.CommandCardHider = CommandCardHider

do
    local stored = {}  -- [pid] -> { frames = {f0..f11}, hidden = bool }

    local function ensureFrames(pid)
        local s = stored[pid]
        if s then return s end
        s = { frames = {}, hidden = false }
        -- Cache references to CommandButton_0..11 for the local player later
        for i = 0, 11 do
            s.frames[i] = nil
        end
        stored[pid] = s
        return s
    end

    local function getFrameByIndex(i)
        -- Note: Frame lookups must be done on the local client that will use them.
        return BlzGetFrameByName("CommandButton_" .. i, 0)
    end

    local function setVisibleLocal(pid, visible)
        if GetLocalPlayer() ~= Player(pid) then return end
        local s = ensureFrames(pid)
        -- Lazy fetch frames once on the local client
        for i = 0, 11 do
            if not s.frames[i] then
                s.frames[i] = getFrameByIndex(i)
            end
            local f = s.frames[i]
            if f then BlzFrameSetVisible(f, visible) end
        end
        s.hidden = (not visible)
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function CommandCardHider.Hide(pid)
        setVisibleLocal(pid, false)
    end

    function CommandCardHider.Show(pid)
        setVisibleLocal(pid, true)
    end

    function CommandCardHider.IsHidden(pid)
        local s = stored[pid]
        return (s and s.hidden) and true or false
    end

    --------------------------------------------------
    -- Wiring (auto-hide/show with Direct Control)
    --------------------------------------------------
    local function directStart(e)
        if not e or e.pid == nil then return end
        CommandCardHider.Hide(e.pid)
    end

    local function directEnd(e)
        if not e or e.pid == nil then return end
        CommandCardHider.Show(e.pid)
    end

    OnInit.final(function()
        -- Respect current state at map start (dev convenience)
        for pid = 0, bj_MAX_PLAYERS - 1 do
            local c = _G.PlayerData and PlayerData.GetControl and PlayerData.GetControl(pid) or nil
            if c and c.direct then
                CommandCardHider.Hide(pid)
            else
                CommandCardHider.Show(pid)
            end
        end

        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("DirectControlStart", directStart)
            PB.On("DirectControlEnd",   directEnd)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CommandCardHider")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
