if Debug and Debug.beginFile then Debug.beginFile("Core_Sanity.lua") end
--==================================================
-- Core_Sanity.lua
-- Shared helpers: ValidUnit, PidOf, IsBag, Emit, SafeGetHero
--==================================================

if not CoreUtils then CoreUtils = {} end
_G.CoreUtils = CoreUtils

do
    function CoreUtils.ValidUnit(u) return u ~= nil and GetUnitTypeId(u) ~= 0 end
    function CoreUtils.PidOf(u)
        if not u then return nil end
        local p = GetOwningPlayer(u); if not p then return nil end
        return GetPlayerId(p)
    end
    function CoreUtils.IsBag(u)
        if _G.BagIgnore and BagIgnore.IsBag then return BagIgnore.IsBag(u) end
        return false
    end
    function CoreUtils.SafeGetHero(pid)
        if _G.PlayerData and PlayerData.GetHero then return PlayerData.GetHero(pid) end
        return nil
    end
    function CoreUtils.Emit(name, payload)
        if _G.ProcBus and ProcBus.Emit then ProcBus.Emit(name, payload) end
    end
    function CoreUtils.Log(system, msg) print("[" .. tostring(system) .. "] " .. tostring(msg)) end

    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then InitBroker.SystemReady("Core_Sanity") end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
