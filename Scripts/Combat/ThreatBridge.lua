if Debug and Debug.beginFile then Debug.beginFile("ThreatBridge.lua") end
--==================================================
-- ThreatBridge.lua
-- Connects CombatEvents → ThreatSystem, SoulEnergy, SpiritDrive.
-- Handles XP, threat, and rage on-hit / on-kill safely.
--==================================================

if not ThreatBridge then ThreatBridge = {} end
_G.ThreatBridge = ThreatBridge

do
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[ThreatBridge] " .. tostring(s)) end
    end

    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function pidOfUnit(u) if u then return GetPlayerId(GetOwningPlayer(u)) end return nil end

    --------------------------------------------------
    -- XP / Spirit helpers
    --------------------------------------------------
    local function giveSoulXP(killer, dead)
        if not validUnit(dead) then return end
        local pid = pidOfUnit(killer)
        if pid == nil then return end

        local base = 0
        if _G.HFILUnitConfig and HFILUnitConfig.GetByFour then
            local row = HFILUnitConfig.GetByFour(GetUnitTypeId(dead))
            if row and row.baseSoul then base = row.baseSoul end
        elseif _G.GameBalance and GameBalance.XP_PER_KILL_BASE then
            base = GameBalance.XP_PER_KILL_BASE
        end
        if base <= 0 then return end

        local bonus = 0
        if _G.PlayerData and PlayerData.GetField then
            bonus = PlayerData.GetField(pid, "xpBonusPercent", 0) or 0
        end
        local final = math.floor(base * (1 + (bonus / 100)) + 0.5)

        if _G.SoulEnergyLogic and SoulEnergyLogic.AddXP then
            SoulEnergyLogic.AddXP(pid, final)
        elseif _G.SoulEnergy and SoulEnergy.Add then
            SoulEnergy.Add(pid, final)
        end
        dprint("kill xp base " .. base .. " bonus " .. bonus .. " final " .. final)
    end

    local function addSpiritDrive(pid, amount)
        if not _G.SpiritDrive or not SpiritDrive.Add then return end
        local add = amount or 0
        if add ~= 0 then
            pcall(SpiritDrive.Add, pid, add)
        end
    end

    --------------------------------------------------
    -- ProcBus wiring
    --------------------------------------------------
    local function wireProcBus()
        local PB = rawget(_G, "ProcBus")
        if not PB or not PB.On then return end

        -- Damage
        PB.On("OnDealtDamage", function(e)
            if not e or not validUnit(e.source) or not validUnit(e.target) then return end
            local pid = e.pid
            local src, tgt, amt = e.source, e.target, e.amount or 0
            if _G.ThreatSystem and ThreatSystem.AddThreat then
                ThreatSystem.AddThreat(src, tgt, amt)
            end
            if pid ~= nil and amt > 0 then
                addSpiritDrive(pid, GameBalance and GameBalance.SD_ON_HIT or 0)
            end
        end)

        -- Kill
        PB.On("OnKill", function(e)
            if not e or not validUnit(e.source) or not validUnit(e.target) then return end
            local killer, dead = e.source, e.target
            local pid = pidOfUnit(killer)
            giveSoulXP(killer, dead)
            if pid ~= nil then
                addSpiritDrive(pid, GameBalance and GameBalance.SD_ON_KILL or 0)
            end
        end)
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        wireProcBus()
        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatBridge")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
