if Debug and Debug.beginFile then Debug.beginFile("SoulEnergyLogic.lua") end
--==================================================
-- SoulEnergyLogic.lua
-- Soul XP: kill-only, pulls baseSoul from HFIL_UnitConfig,
-- optional group-share via AggroManager, per-player bonus,
-- emits ProcBus updates.
--==================================================

if not SoulEnergyLogic then SoulEnergyLogic = {} end
_G.SoulEnergyLogic = SoulEnergyLogic
if not SoulEnergy then SoulEnergy = {} end
_G.SoulEnergy = SoulEnergy

do
    local function DEV_ON()
        local DM = rawget(_G, "DevMode")
        if DM then
            if type(DM.IsOn) == "function" then return DM.IsOn(0) end
            if type(DM.IsEnabled) == "function" then return DM.IsEnabled() end
        end
        return false
    end
    local function dprint(msg) if DEV_ON() then print("[SoulLogic] " .. tostring(msg)) end end

    local UI_PING_MIN = 1

    local P = {}
    local function PD(pid) P[pid] = P[pid] or { value = 0 }; return P[pid] end

    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, e) end
    end

    function SoulEnergyLogic.Get(pid) return PD(pid).value or 0 end

    function SoulEnergyLogic.Set(pid, value)
        local v = math.max(0, math.floor(value or 0))
        PD(pid).value = v
        emit("OnSoulChanged", { pid = pid, value = v })
        return v
    end

    function SoulEnergyLogic.Add(pid, delta)
        local pd = PD(pid)
        local v = math.max(0, math.floor((pd.value or 0) + (delta or 0)))
        local diff = v - (pd.value or 0)
        pd.value = v
        emit("OnSoulChanged", { pid = pid, value = v })
        if math.abs(diff) >= UI_PING_MIN then
            emit("OnSoulPing", { pid = pid, delta = diff })
        end
        return v
    end

    function SoulEnergyLogic.Spend(pid, cost)
        local pd = PD(pid)
        local cur = pd.value or 0
        if cur < (cost or 0) then return false end
        pd.value = cur - (cost or 0)
        emit("OnSoulChanged", { pid = pid, value = pd.value })
        return true
    end

    function SoulEnergyLogic.Ping(pid, amount)
        emit("OnSoulPing", { pid = pid, delta = amount or 0 })
    end

    -- ---------- Reward lookup (robust to either API) ----------
    function SoulEnergyLogic.GetReward(rawTypeId)
        local HUC = rawget(_G, "HFILUnitConfig")
        if not HUC or type(rawTypeId) ~= "number" then return 0 end
        local row = nil
        if HUC.GetByFour then
            row = HUC.GetByFour(rawTypeId)
        elseif HUC.GetByTypeId then
            row = HUC.GetByTypeId(rawTypeId)
        end
        if row and row.baseSoul then return math.floor(row.baseSoul) end
        return 0
    end

    -- ---------- Group share ----------
    local function collectParticipants(deadUnit, killerPid)
        local list = {}

        local row = nil
        if _G.HFILUnitConfig and HFILUnitConfig.GetByFour then
            row = HFILUnitConfig.GetByFour(GetUnitTypeId(deadUnit))
        elseif _G.HFILUnitConfig and HFILUnitConfig.GetByTypeId then
            row = HFILUnitConfig.GetByTypeId(GetUnitTypeId(deadUnit))
        end

        local share = (row and row.share) == true
        if share and rawget(_G, "AggroManager") and AggroManager.GetGroupForTarget then
            local handles = AggroManager.GetGroupForTarget(deadUnit)
            if handles and #handles > 0 then
                for i = 1, #handles do
                    local u = handles[i]
                    if type(u) == "userdata" and GetUnitTypeId(u) ~= 0 then
                        local p = GetOwningPlayer(u)
                        if p then list[#list + 1] = GetPlayerId(p) end
                    elseif type(u) == "number" then
                        list[#list + 1] = u
                    end
                end
            end
        end

        if #list == 0 then list[1] = killerPid end

        local uniq, out = {}, {}
        for i = 1, #list do
            local pid = list[i]
            if pid ~= nil and not uniq[pid] then
                uniq[pid] = true
                out[#out + 1] = pid
            end
        end
        return out
    end

    local function xpWithBonus(pid, baseShare)
        local bonusPct = 0
        if rawget(_G, "PlayerData") and PlayerData.GetField then
            bonusPct = PlayerData.GetField(pid, "xpBonusPercent", 0) or 0
        end
        local final = math.floor(baseShare * (1 + (bonusPct / 100)) + 0.5)
        return final, bonusPct
    end

    -- ---------- Award from kill ----------
    local function awardFromKill(e)
        if not e then return end
        local dead  = e.target
        local killer= e.source
        if not dead or GetUnitTypeId(dead) == 0 then return end

        local base = SoulEnergyLogic.GetReward(GetUnitTypeId(dead)) or 0
        if base <= 0 then
            dprint("kill ignored (base 0)")
            return
        end

        local killerPid = e.pid
        if killerPid == nil and killer then
            local p = GetOwningPlayer(killer)
            if p then killerPid = GetPlayerId(p) end
        end
        if killerPid == nil then
            dprint("no killer pid; abort share")
            return
        end

        local participants = collectParticipants(dead, killerPid)
        local count = #participants
        local share = math.max(1, math.floor(base / math.max(1, count)))

        dprint("kill base " .. tostring(base) .. " share " .. tostring(share) .. " parts " .. tostring(count))

        for i = 1, count do
            local pid = participants[i]
            local final, bonusPct = xpWithBonus(pid, share)
            SoulEnergyLogic.Add(pid, final)
            if bonusPct ~= 0 then
                dprint("pid " .. tostring(pid) .. " +bonus " .. tostring(bonusPct) .. " final " .. tostring(final))
            end
        end
    end

    local function wireBus()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnKill", awardFromKill)
        end
    end

    -- Adapter passthroughs
    function SoulEnergy.Get(pid)      return SoulEnergyLogic.Get(pid) end
    function SoulEnergy.Set(pid, v)   return SoulEnergyLogic.Set(pid, v) end
    function SoulEnergy.Add(pid, d)   return SoulEnergyLogic.Add(pid, d) end
    function SoulEnergy.Spend(pid, c) return SoulEnergyLogic.Spend(pid, c) end
    function SoulEnergy.Ping(pid, a)  return SoulEnergyLogic.Ping(pid, a) end

    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYERS - 1 do PD(pid) end
        wireBus()
        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SoulEnergyLogic")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
