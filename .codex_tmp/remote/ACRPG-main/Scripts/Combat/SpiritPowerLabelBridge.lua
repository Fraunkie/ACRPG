if Debug and Debug.beginFile then Debug.beginFile("SpiritPowerLabelBridge.lua") end
--==================================================
-- SpiritPowerLabelBridge.lua
-- Lightweight UI updater for SpiritDrive + SoulEnergy labels.
-- • Debounced to avoid spam.
-- • Multiplayer safe (local frame visibility).
--==================================================

if not SpiritPowerLabelBridge then SpiritPowerLabelBridge = {} end
_G.SpiritPowerLabelBridge = SpiritPowerLabelBridge

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local UPDATE_DELAY = 0.15 -- seconds between UI updates per player

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local labels = {}     -- labels[pid] = { frame, lastValue }
    local pending = {}    -- debounce queue
    local lastUpdate = {} -- pid -> os.clock

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[SpiritPowerLabel] " .. tostring(s)) end
    end

    local function now()
        if os and os.clock then return os.clock() end
        return 0
    end

    --------------------------------------------------
    -- Core UI setup
    --------------------------------------------------
    local function ensureLabel(pid)
        local data = labels[pid]
        if data and data.frame then return data.frame end

        local parent = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local frame = BlzCreateFrameByType("TEXT", "SpiritLabel" .. pid, parent, "", 0)
        BlzFrameSetSize(frame, 0.12, 0.012)
        BlzFrameSetPoint(frame, FRAMEPOINT_TOPRIGHT, parent, FRAMEPOINT_TOPRIGHT, -0.030, -0.030 - (pid * 0.016))
        BlzFrameSetText(frame, "Spirit: 0 | Soul: 0")
        BlzFrameSetScale(frame, 1.00)
        BlzFrameSetVisible(frame, GetLocalPlayer() == Player(pid))

        labels[pid] = { frame = frame, lastValue = "Spirit: 0 | Soul: 0" }
        return frame
    end

    local function setText(pid, text)
        local entry = labels[pid]
        if not entry then entry = { frame = ensureLabel(pid) } end
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetText(entry.frame, text)
        end
        entry.lastValue = text
    end

    --------------------------------------------------
    -- Public interface
    --------------------------------------------------
    function SpiritPowerLabelBridge.SetSpirit(pid, val, max)
        local old = labels[pid] and labels[pid].lastValue or ""
        local txt = "Spirit: " .. tostring(math.floor(val or 0)) .. " / " .. tostring(max or 100)
        local sVal = SoulEnergy and SoulEnergy.Get and SoulEnergy.Get(pid) or 0
        local line = txt .. " | Soul: " .. tostring(sVal)
        if old ~= line then
            setText(pid, line)
        end
    end

    function SpiritPowerLabelBridge.PingSpirit(pid, delta)
        if delta == 0 then return end
        dprint("Spirit ping " .. tostring(delta))
    end

    function SpiritPowerLabelBridge.SetSoul(pid, val)
        local old = labels[pid] and labels[pid].lastValue or ""
        local txt = "Soul: " .. tostring(math.floor(val or 0))
        local sd = SpiritDrive and SpiritDrive.Get and SpiritDrive.Get(pid)
        local sVal = sd and select(1, sd) or 0
        local sMax = sd and select(2, sd) or 100
        local line = "Spirit: " .. tostring(math.floor(sVal)) .. " / " .. tostring(sMax) .. " | " .. txt
        if old ~= line then
            setText(pid, line)
        end
    end

    function SpiritPowerLabelBridge.PingSoul(pid, delta)
        if delta == 0 then return end
        dprint("Soul ping " .. tostring(delta))
    end

    --------------------------------------------------
    -- Debounced refresh
    --------------------------------------------------
    local function refreshAll()
        local tNow = now()
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            local last = lastUpdate[pid] or 0
            if (tNow - last) >= UPDATE_DELAY then
                lastUpdate[pid] = tNow
                local vS, mS = 0, 100
                if _G.SpiritDrive and SpiritDrive.Get then
                    vS, mS = SpiritDrive.Get(pid)
                end
                local vE = 0
                if _G.SoulEnergy and SoulEnergy.Get then
                    vE = SoulEnergy.Get(pid)
                end
                local text = "Spirit: " .. math.floor(vS or 0) .. "/" .. math.floor(mS or 100) .. " | Soul: " .. math.floor(vE or 0)
                setText(pid, text)
            end
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            ensureLabel(pid)
        end
        local t = CreateTimer()
        TimerStart(t, UPDATE_DELAY, true, refreshAll)
        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SpiritPowerLabelBridge")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
