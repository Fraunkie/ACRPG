if Debug and Debug.beginFile then Debug.beginFile("SpiritPowerLabelBridge.lua") end
--==================================================
-- SpiritPowerLabelBridge.lua
-- Updates SoulEnergy + SpiritDrive UI text labels.
-- • Update(pid, current, max)
-- • UpdateSoul(pid, total)
-- • Debounced so values don’t spam text updates.
--==================================================

if not SpiritPowerLabelBridge then SpiritPowerLabelBridge = {} end
_G.SpiritPowerLabelBridge = SpiritPowerLabelBridge

do
    local lastSoul = {}
    local lastSpirit = {}
    local lastUpdate = {}
    local DEBOUNCE = 0.3

    local function now()
        return (os and os.clock and os.clock()) or 0
    end

    local function safeText(pid, msg)
        if GetLocalPlayer() == Player(pid) then
            DisplayTextToPlayer(Player(pid), 0, 0, msg)
        end
    end

    --------------------------------------------------
    -- Soul Energy UI
    --------------------------------------------------
    function SpiritPowerLabelBridge.UpdateSoul(pid, value)
        local v = math.floor(value or 0)
        if v ~= lastSoul[pid] then
            lastSoul[pid] = v
            safeText(pid, "Soul Energy: " .. tostring(v))
        end
    end

    --------------------------------------------------
    -- Spirit Drive UI
    --------------------------------------------------
    function SpiritPowerLabelBridge.Update(pid, current, max)
        local t = now()
        if (lastUpdate[pid] or 0) + DEBOUNCE > t then return end
        lastUpdate[pid] = t

        local cur = math.floor(current or 0)
        local mx  = math.floor(max or 0)
        if cur ~= (lastSpirit[pid] or -1) then
            lastSpirit[pid] = cur
            safeText(pid, "Spirit Drive: " .. tostring(cur) .. "/" .. tostring(mx))
        end
    end

    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SpiritPowerLabelBridge")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
