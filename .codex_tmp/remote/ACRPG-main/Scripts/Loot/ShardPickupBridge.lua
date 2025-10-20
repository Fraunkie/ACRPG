if Debug and Debug.beginFile then Debug.beginFile("ShardPickupBridge.lua") end
--==================================================
-- ShardPickupBridge.lua
-- Routes item pickups to ShardSystem and emits a general pickup event.
--==================================================

if not ShardPickupBridge then ShardPickupBridge = {} end
_G.ShardPickupBridge = ShardPickupBridge

do
    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[ShardPickup] " .. tostring(s)) end
    end

    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, e) end
    end

    local function shouldIgnore(pid, item)
        if _G.ShardIgnoreForce and ShardIgnoreForce.ShouldIgnore then
            local ok, res = pcall(ShardIgnoreForce.ShouldIgnore, pid, item)
            if ok and res then return true end
        end
        return false
    end

    local function isShard(item)
        if not _G.ShardSystem or not ShardSystem.IsShardItemHandle then return false end
        local ok, res = pcall(ShardSystem.IsShardItemHandle, item)
        return ok and res == true
    end

    local function isFragment(item)
        if not item then return false end
        local it = GetItemTypeId(item)
        if _G.ShardFragments and ShardFragments.ValueForItem then
            local ok, v = pcall(ShardFragments.ValueForItem, it)
            if ok and type(v) == "number" and v > 0 then
                return true
            end
        end
        return false
    end

    --------------------------------------------------
    -- Core handler
    --------------------------------------------------
    local function handlePickup(p, item)
        local pid = GetPlayerId(p)
        if not item then return end

        -- Broadcast for any listeners first
        emit("OnItemPickedUp", { pid = pid, item = item })

        if shouldIgnore(pid, item) then
            dprint("pickup suppressed for pid " .. tostring(pid))
            return
        end

        if isFragment(item) and _G.ShardSystem and ShardSystem.OnShardFragmentPickup then
            ShardSystem.OnShardFragmentPickup(pid, item)
            return
        end

        if isShard(item) and _G.ShardSystem and ShardSystem.OnShardCorePickup then
            ShardSystem.OnShardCorePickup(pid, item)
            return
        end
    end

    --------------------------------------------------
    -- Wiring: native fallback and optional ProcBus
    --------------------------------------------------
    local function wireNative()
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_PICKUP_ITEM, nil)
        end
        TriggerAddAction(t, function()
            handlePickup(GetTriggerPlayer(), GetManipulatedItem())
        end)
    end

    local function wireProcBus()
        local PB = rawget(_G, "ProcBus")
        if not PB or not PB.On then return end
        PB.On("OnUnitPickedUpItem", function(e)
            if not e or not e.player or not e.item then return end
            handlePickup(e.player, e.item)
        end)
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    if OnInit and OnInit.final then
        OnInit.final(function()
            wireNative()
            wireProcBus()
            if rawget(_G, "InitBroker") and InitBroker.SystemReady then
                InitBroker.SystemReady("ShardPickupBridge")
            end
        end)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
