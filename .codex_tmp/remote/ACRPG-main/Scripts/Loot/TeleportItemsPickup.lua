if Debug and Debug.beginFile then Debug.beginFile("TeleportItemsPickup.lua") end
--==================================================
-- TeleportItemsPickup.lua
-- Handles teleport key item pickups.
-- • Ignores bag units completely.
-- • Works with TeleportSystem and ItemDatabase.
--==================================================

if not TeleportItemsPickup then TeleportItemsPickup = {} end
_G.TeleportItemsPickup = TeleportItemsPickup

do
    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function isBag(u)
        return u and GetUnitTypeId(u) == FourCC("hBAG") -- your bag rawcode
    end
    local function pidOf(u)
        local p = GetOwningPlayer(u)
        return p and GetPlayerId(p) or nil
    end

    --------------------------------------------------
    -- Core
    --------------------------------------------------
    local function onPickup()
        local u = GetTriggerUnit()
        local i = GetManipulatedItem()
        if not validUnit(u) or not validItem(i) then return end
        if isBag(u) then
            RemoveItem(i)
            return
        end
        local pid = pidOf(u)
        if not pid then return end

        local id = GetItemTypeId(i)
        local node = ItemDatabase.TeleportNodeByItem(id)
        if node and _G.TeleportSystem and TeleportSystem.Unlock then
            TeleportSystem.Unlock(pid, node)
            DisplayTextToPlayer(Player(pid), 0, 0, "|cff88ff88Unlocked teleport:|r " .. tostring(node))
        end

        RemoveItem(i)
    end

    --------------------------------------------------
    -- Hook
    --------------------------------------------------
    local function hook()
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_PICKUP_ITEM, nil)
        end
        TriggerAddAction(t, onPickup)
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        hook()
        print("[TeleportItemsPickup] ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("TeleportItemsPickup")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
