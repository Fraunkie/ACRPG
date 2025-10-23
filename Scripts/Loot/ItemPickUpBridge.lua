if Debug and Debug.beginFile then Debug.beginFile("ItemPickupBridge.lua") end
--==================================================
-- ItemPickupBridge.lua  (Early-destroy route + IsFull pre-check)
-- • On pickup: snapshot typeId/pos, immediately RemoveItem()
-- • Ask custom inventory to add; if refused, recreate item on ground
-- • Scrub any native copies that slipped into WC3 inventory
--==================================================

if not ItemPickupBridge then ItemPickupBridge = {} end
_G.ItemPickupBridge = ItemPickupBridge

do
    local function dbg(msg)
        if Debug and Debug.printf then Debug.printf("[ItemPickupBridge] " .. tostring(msg)) end
    end

    local function deleteItem(it)
        if it ~= nil then
            SetItemVisible(it, false)
            RemoveItem(it)
            return true
        end
        return false
    end

    local function removeOneFromHero(u, typeId)
        if u == nil then return false end
        local slots = UnitInventorySize(u) or 6
        local i = 0
        while i < slots do
            local h = UnitItemInSlot(u, i)
            if h ~= nil and GetItemTypeId(h) == typeId then
                SetItemVisible(h, false)
                RemoveItem(h)
                return true
            end
            i = i + 1
        end
        return false
    end

    local function addToCustom(pid, typeId)
        if _G.PlayerMenu_InventoryModule and PlayerMenu_InventoryModule.AddItem then
            local ok, res = pcall(PlayerMenu_InventoryModule.AddItem, pid, typeId)
            return (ok and res == true)
        end
        return false
    end

    local function isCustomFull(pid)
        if _G.PlayerMenu_InventoryModule and PlayerMenu_InventoryModule.IsFull then
            local ok, res = pcall(PlayerMenu_InventoryModule.IsFull, pid)
            if ok then return res == true end
        end
        return true -- conservative: treat as full if unknown
    end

    local guard = {}  -- per-pid reentrancy guard

    local function handlePickup(pid, hero, manipulated)
        if guard[pid] then
            dbg("guard active; skip")
            return
        end
        guard[pid] = true

        local typeId = GetItemTypeId(manipulated)
        local x, y   = GetUnitX(hero), GetUnitY(hero)

        -- Destroy the native handle immediately
        deleteItem(manipulated)
        removeOneFromHero(hero, typeId)

        local added = false

        -- If we already know it's full, skip the add and recreate on ground
        if not isCustomFull(pid) then
            added = addToCustom(pid, typeId)
        end

        if not added then
            CreateItem(typeId, x, y)
            dbg("custom inv declined or full; recreated item on ground typeId=" .. tostring(typeId))
        else
            -- scrub in case something re-inserted it
            TimerStart(CreateTimer(), 0.00, false, function()
                removeOneFromHero(hero, typeId)
                DestroyTimer(GetExpiredTimer())
            end)
            TimerStart(CreateTimer(), 0.05, false, function()
                removeOneFromHero(hero, typeId)
                DestroyTimer(GetExpiredTimer())
            end)
            dbg("routed to custom inventory typeId=" .. tostring(typeId))
        end

        guard[pid] = nil
    end

    local function onPickup()
        local p   = GetTriggerPlayer()
        local pid = GetPlayerId(p)
        local u   = GetTriggerUnit()
        local it  = GetManipulatedItem()
        if u ~= nil and it ~= nil then
            handlePickup(pid, u, it)
        end
    end

    OnInit.final(function()
        local t = CreateTrigger()
        local i = 0
        while i < bj_MAX_PLAYER_SLOTS do
            TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_PICKUP_ITEM, nil)
            i = i + 1
        end
        TriggerAddAction(t, onPickup)
        dbg("ready (early-destroy route + IsFull pre-check)")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ItemPickupBridge")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
