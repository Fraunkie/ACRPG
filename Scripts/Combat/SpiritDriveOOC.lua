if Debug and Debug.beginFile then Debug.beginFile("SpiritDriveOOC.lua") end
--==================================================
-- SpiritDriveOOC.lua
-- Simple out-of-combat helper for SpiritDrive/UI.
-- • IsOutOfCombat(pid) -> bool
--==================================================

if not SpiritDriveOOC then SpiritDriveOOC = {} end
_G.SpiritDriveOOC = SpiritDriveOOC

do
    local function inCombat(pid)
        if _G.CombatEventsBridge and CombatEventsBridge.IsInCombat then
            return CombatEventsBridge.IsInCombat(pid)
        end
        return false
    end

    function SpiritDriveOOC.IsOutOfCombat(pid)
        return not inCombat(pid)
    end

    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SpiritDriveOOC")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
