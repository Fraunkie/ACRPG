if Debug and Debug.beginFile then Debug.beginFile("InventoryPickupBridge.lua") end
--==================================================
-- InventoryPickupBridge.lua
-- Sends picked up items to the custom Inventory (no shards, no fragments).
-- Works whether the Inventory UI is open or not.
--==================================================

do
  local function dprint(msg)
    if Debug and Debug.printf then Debug.printf("[InvPickup] " .. tostring(msg)) end
  end

  local function addToInventory(pid, typeId)
    local INV = _G.PlayerMenu_InventoryModule
    if not INV or not INV.AddItem then
      dprint("Inventory module not ready; queued add failed for pid=" .. tostring(pid))
      return
    end
    INV.AddItem(pid, typeId)
  end

  local function onPickup(player, item)
    if not item then return end
    local pid   = GetPlayerId(player)
    local typeId = GetItemTypeId(item)
    if typeId == 0 then return end

    -- prevent WC3 inventory: we immediately remove the item object from the map
    removeitem(item)

    dprint("picked typeId " .. tostring(typeId))
    addToInventory(pid, typeId)
  end

  -- Native trigger for all players
  local t = CreateTrigger()
  for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
    TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_PICKUP_ITEM, nil)
  end
  TriggerAddAction(t, function()
    onPickup(GetTriggerPlayer(), GetManipulatedItem())
  end)

  if rawget(_G, "InitBroker") and InitBroker.SystemReady then
    InitBroker.SystemReady("InventoryPickupBridge")
  end
end

if Debug and Debug.endFile then Debug.endFile() end
