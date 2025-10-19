if Debug and Debug.beginFile then Debug.beginFile("ThreatSystem_RespawnHelpers.lua") end
--==================================================
-- ThreatSystem_RespawnHelpers.lua
-- Thin helpers for creep respawn integration.
-- Keeps core ThreatSystem untouched; safe to include multiple times.
--==================================================

do
    if not ThreatSystem then
        ThreatSystem = {}
        _G.ThreatSystem = ThreatSystem
    end

    -- Internal aux tables (do not rely on metatables; WC3-safe)
    ThreatSystem._eliteFlagByUnit = ThreatSystem._eliteFlagByUnit or {}
    ThreatSystem._eliteMultByUnit = ThreatSystem._eliteMultByUnit or {}
    ThreatSystem._packIdByUnit    = ThreatSystem._packIdByUnit or {}

    --------------------------------------------------
    -- Safe checker for unit validity
    --------------------------------------------------
    local function ValidUnit(u)
        return u ~= nil and GetUnitTypeId(u) ~= 0
    end

    --------------------------------------------------
    -- Public helpers (used by CreepRespawnSystem)
    --------------------------------------------------

    -- Registers a spawned creep with optional elite flag and pack link.
    if not ThreatSystem.OnCreepSpawn then
        function ThreatSystem.OnCreepSpawn(u, isElite, packId)
            if not ValidUnit(u) then return end

            -- Prefer existing Register API names from your core system
            if ThreatSystem.RegisterEnemy then
                ThreatSystem.RegisterEnemy(u)
            elseif ThreatSystem.Register then
                ThreatSystem.Register(u)
            end

            -- Track elite state and pack link for HUD or multipliers
            ThreatSystem._eliteFlagByUnit[u] = isElite and true or false

            if isElite then
                -- Default damage multiplier storage for future use by the core system
                -- (your AddThreat can consult this if desired)
                local gb = _G.GameBalance
                local mult = 2.0
                if gb and gb.Threat and gb.Threat.Elite and gb.Threat.Elite.dmgMult then
                    mult = gb.Threat.Elite.dmgMult
                end
                ThreatSystem._eliteMultByUnit[u] = mult
            else
                ThreatSystem._eliteMultByUnit[u] = 1.0
            end

            if packId ~= nil then
                ThreatSystem._packIdByUnit[u] = packId
            end
        end
    end

    -- Clears a creep from tracking on death or despawn.
    if not ThreatSystem.OnCreepDeath then
        function ThreatSystem.OnCreepDeath(u)
            if not u then return end

            -- Clear incoming threat first if available
            if ThreatSystem.ClearUnit then
                ThreatSystem.ClearUnit(u)
            end

            -- Remove from core registry
            if ThreatSystem.Unregister then
                ThreatSystem.Unregister(u)
            elseif ThreatSystem.Remove then
                ThreatSystem.Remove(u)
            end

            -- Wipe aux flags
            ThreatSystem._eliteFlagByUnit[u] = nil
            ThreatSystem._eliteMultByUnit[u] = nil
            ThreatSystem._packIdByUnit[u]    = nil
        end
    end

    -- Optional: set a custom elite multiplier at runtime for a unit.
    if not ThreatSystem.SetEliteMultiplier then
        function ThreatSystem.SetEliteMultiplier(u, mult)
            if not ValidUnit(u) then return end
            if type(mult) ~= "number" or mult <= 0 then return end
            ThreatSystem._eliteMultByUnit[u] = mult
        end
    end

    -- Optional: associate or change the pack link of a unit.
    if not ThreatSystem.SetPackLink then
        function ThreatSystem.SetPackLink(u, packId)
            if not ValidUnit(u) then return end
            ThreatSystem._packIdByUnit[u] = packId
        end
    end

    --------------------------------------------------
    -- Lightweight getters (useful for HUD or bridges)
    --------------------------------------------------
    if not ThreatSystem.IsEliteUnit then
        function ThreatSystem.IsEliteUnit(u)
            return ThreatSystem._eliteFlagByUnit[u] == true
        end
    end

    if not ThreatSystem.GetEliteMult then
        function ThreatSystem.GetEliteMult(u)
            local m = ThreatSystem._eliteMultByUnit[u]
            if type(m) == "number" then return m end
            return 1.0
        end
    end

    if not ThreatSystem.GetPackId then
        function ThreatSystem.GetPackId(u)
            return ThreatSystem._packIdByUnit[u]
        end
    end
end

-- Ready banner
if InitBroker and InitBroker.SystemReady then
    InitBroker.SystemReady("ThreatSystem_RespawnHelpers")
end

if Debug and Debug.endFile then Debug.endFile() end
