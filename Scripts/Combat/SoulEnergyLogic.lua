if Debug and Debug.beginFile then Debug.beginFile("SoulEnergyLogic.lua") end
--==================================================
-- SoulEnergyLogic.lua
-- Core Soul XP economy:
--  • XP only on kill (no gain on hit)
--  • Pulls baseSoul from HFIL_UnitConfig
--  • Optional group-share via AggroManager
--  • Per-player xpBonusPercent applied AFTER split
--  • Emits ProcBus OnSoulChanged / OnSoulPing
--  • No percent glyphs in strings (editor-safe)
--==================================================

if not SoulEnergyLogic then SoulEnergyLogic = {} end
_G.SoulEnergyLogic = SoulEnergyLogic
if not SoulEnergy then SoulEnergy = {} end -- adapter may shadow, but we keep API
_G.SoulEnergy = SoulEnergy

do
    --------------------------------------------------
    -- Dev prints (gated)
    --------------------------------------------------
    local function DEV_ON()
        local DM = rawget(_G, "DevMode")
        if DM then
            if type(DM.IsOn) == "function" then return DM.IsOn(0) end
            if type(DM.IsEnabled) == "function" then return DM.IsEnabled() end
        end
        return false
    end
    local function dprint(msg) if DEV_ON() then print("[SoulLogic] " .. tostring(msg)) end end

    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local UI_PING_MIN = 1   -- minimum delta to ping UI when changed

    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- P[pid] = { value = n }
    local P = {}

    local function PD(pid)
        local t = P[pid]
        if not t then
            t = { value = 0 }
            P[pid] = t
        end
        return t
    end

    --------------------------------------------------
    -- Emit helpers
    --------------------------------------------------
    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, e) end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function SoulEnergyLogic.Get(pid)
        return PD(pid).value or 0
    end

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

    --------------------------------------------------
    -- Reward lookup from HFIL_UnitConfig
    --------------------------------------------------
    function SoulEnergyLogic.GetReward(rawTypeId)
        -- rawTypeId here is numeric (GetUnitTypeId)
        local HUC = rawget(_G, "HFILUnitConfig")
        if not HUC then return 0 end
        if type(rawTypeId) ~= "number" then return 0 end
        if HUC.GetByFour then
            local row = HUC.GetByFour(rawTypeId)
            if row and row.baseSoul then return math.floor(row.baseSoul) end
        end
        return 0
    end

    --------------------------------------------------
    -- Group sharing
    -- Returns array of participant pids; falls back to killer pid only.
    --------------------------------------------------
    local function collectParticipants(deadUnit, killerPid)
        local list = {}

        -- Try config flag on the creeps row
        local row = nil
        if _G.HFILUnitConfig and HFILUnitConfig.GetByFour then
            row = HFILUnitConfig.GetByFour(GetUnitTypeId(deadUnit))
        end

        local share = (row and row.share) == true
        if share and rawget(_G, "AggroManager") and AggroManager.GetGroupForTarget then
            local handles = AggroManager.GetGroupForTarget(deadUnit) -- returns array of unit handles (or pids)
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

        if #list == 0 then
            list[1] = killerPid
        end

        -- de-dup
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

    --------------------------------------------------
    -- Bonus percent (per-player, from PlayerData)
    --------------------------------------------------
    local function xpWithBonus(pid, baseShare)
        local bonusPct = 0
        if rawget(_G, "PlayerData") and PlayerData.GetField then
            bonusPct = PlayerData.GetField(pid, "xpBonusPercent", 0) or 0
        end
        local final = math.floor(baseShare * (1 + (bonusPct / 100)) + 0.5)
        return final, bonusPct
    end

    --------------------------------------------------
    -- Award XP from kill event payload
    --------------------------------------------------
    local function awardFromKill(e)
        -- Expect e.pid (killer pid), e.source (killer unit), e.target (dead unit)
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

    --------------------------------------------------
    -- Bus wiring (kill-only)
    --------------------------------------------------
    local function wireBus()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnKill", awardFromKill)
            -- No gain on hit; keep Souls strictly kill-based
        end
    end

    --------------------------------------------------
    -- Adapter passthroughs for SoulEnergy (UI/Chat may use these)
    --------------------------------------------------
    function SoulEnergy.Get(pid)      return SoulEnergyLogic.Get(pid) end
    function SoulEnergy.Set(pid, v)   return SoulEnergyLogic.Set(pid, v) end
    function SoulEnergy.Add(pid, d)   return SoulEnergyLogic.Add(pid, d) end
    function SoulEnergy.Spend(pid, c) return SoulEnergyLogic.Spend(pid, c) end
    function SoulEnergy.Ping(pid, a)  return SoulEnergyLogic.Ping(pid, a) end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
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
