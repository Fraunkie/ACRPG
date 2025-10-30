if Debug and Debug.beginFile then Debug.beginFile("SpiritPowerLabelBridge.lua") end
--==================================================
-- SpiritPowerLabelBridge.lua
-- Updates SpiritDrive UI labels (and the bar).
-- • Update(pid, current, max)  -- call this from your SD system
--==================================================

if not SpiritPowerLabelBridge then SpiritPowerLabelBridge = {} end
_G.SpiritPowerLabelBridge = SpiritPowerLabelBridge

do
    local lastSpirit = {}
    local lastT = {}
    local DEBOUNCE = 0.15

    local function now()
        return (os and os.clock and os.clock()) or 0
    end



    function SpiritPowerLabelBridge.Update(pid, current, max)
        local t = now()
        if (lastT[pid] or 0) + DEBOUNCE > t then return end
        lastT[pid] = t

        local cur = math.floor(tonumber(current) or 0)
        local mx  = math.max(1, math.floor(tonumber(max) or 100))

        -- Push into the bar so the orange number above HP changes immediately
        if _G.CustomSpiritDriveBar and CustomSpiritDriveBar.Set then
            CustomSpiritDriveBar.Set(pid, cur, mx)
        end
    end

    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SpiritPowerLabelBridge")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
