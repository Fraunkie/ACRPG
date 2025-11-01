if Debug and Debug.beginFile then Debug.beginFile("AscensionSystem.lua") end
--==================================================
-- AscensionSystem.lua
-- Core tier logic and ascension completion handling.
--==================================================

if not AscensionSystem then AscensionSystem = {} end
_G.AscensionSystem = AscensionSystem

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local GB = GameBalance or {}
    local MIN_TIER = GB.MIN_TIER_FOR_ASCENSION or 0
    local MIN_POWER = GB.MIN_POWER_FOR_ASCENSION or 0
    local REQUIRE_FULL_SD = GB.RequireFullSpiritDrive or true

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[Ascension] " .. tostring(s)) end
    end

    local function PD(pid)
        if not PLAYER_DATA then PLAYER_DATA = {} end
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        local pd = PLAYER_DATA[pid]
        pd.tier = pd.tier or 0
        pd.powerLevel = pd.powerLevel or 0
        pd.family = pd.family or "GENERIC"
        return pd
    end

    local function emit(name, data)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, data) end
    end

    local function hasChargedShard(pid)
        if not _G.ShardChargeSystem or not ShardChargeSystem.HasChargedShard then return false end
        local ok, res = pcall(ShardChargeSystem.HasChargedShard, pid)
        return ok and res
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function AscensionSystem.GetAvailableTier(pid)
        local pd = PD(pid)
        local nextTier = (pd.tier or 0) + 1
        return nextTier
    end

    function AscensionSystem.CanAscendNow(pid, desiredTier)
        local pd = PD(pid)
        local tier = desiredTier or (pd.tier + 1)

        if tier <= (pd.tier or 0) then
            return false, "already at or above tier"
        end

        if pd.powerLevel < (MIN_POWER or 0) then
            return false, "power too low"
        end

        if REQUIRE_FULL_SD and _G.SpiritDrive and SpiritDrive.Get then
            local val, max = SpiritDrive.Get(pid)
            if val < max then
                return false, "spirit drive not full"
            end
        end

        if not hasChargedShard(pid) then
            return false, "no charged shard"
        end

        return true, nil
    end

    function AscensionSystem.TryAscend(pid, desiredTier)
        local can, reason = AscensionSystem.CanAscendNow(pid, desiredTier)
        if not can then
            dprint("blocked: " .. tostring(reason))
            emit("OnAscendBlocked", { pid = pid, reason = reason })
            return false
        end

        local pd = PD(pid)
        local tier = desiredTier or (pd.tier + 1)
        pd.tier = tier

        -- reset spirit drive and consume shard
        if _G.SpiritDrive and SpiritDrive.Reset then SpiritDrive.Reset(pid) end
        if _G.ShardChargeSystem and ShardChargeSystem.ConsumeChargedShard then
            pcall(ShardChargeSystem.ConsumeChargedShard, pid)
        end

        -- optional lives restore
        if _G.LivesSystem and LivesSystem.OnAscended then
            pcall(LivesSystem.OnAscended, pid)
        end

        -- notify GameBalance hook
        if GB.OnAscendComplete then
            pcall(GB.OnAscendComplete, pid, tier, pd.family)
        end

        emit("OnAscendComplete", { pid = pid, tier = tier, familyKey = pd.family })
        dprint("ascend success tier " .. tostring(tier))
        return true
    end

    --------------------------------------------------
    -- Dev / debug helpers
    --------------------------------------------------
    function AscensionSystem.SetTier(pid, val)
        local pd = PD(pid)
        pd.tier = math.max(0, math.floor(val or 0))
        dprint("set tier to " .. tostring(pd.tier))
        emit("OnTierSet", { pid = pid, tier = pd.tier })
    end

    function AscensionSystem.GetTier(pid)
        return PD(pid).tier or 0
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    if OnInit and OnInit.final then
        OnInit.final(function()
            dprint("ready")
            if rawget(_G, "InitBroker") and InitBroker.SystemReady then
                InitBroker.SystemReady("AscensionSystem")
            end
        end)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
