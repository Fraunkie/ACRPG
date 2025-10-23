if Debug and Debug.beginFile then Debug.beginFile("InventoryService.lua") end
--==================================================
-- InventoryService.lua (v2.4 - Bag+Equip, Stat-aware + Gates)
--==================================================

if not InventoryService then InventoryService = {} end
_G.InventoryService = InventoryService

do
    local CAP_DEFAULT = 24  -- 4x6 grid

    local EQUIP_SLOTS = {
        "Head", "Cloak", "Amulet", "Bracers",
        "Weapon", "Chest", "Shield",
        "Legs", "Boots",
        "Accessory", "Ring", "Necklace"
    }

    local CATEGORY_TO_SLOT = {
        HEAD      = "Head",
        CLOAK     = "Cloak",
        AMULET    = "Amulet",
        NECKLACE  = "Amulet",
        BRACERS   = "Bracers",
        HANDS     = "Bracers",
        WEAPON    = "Weapon",
        OFFHAND   = "Shield",
        SHIELD    = "Shield",
        CHEST     = "Chest",
        LEGS      = "Legs",
        BOOTS     = "Boots",
        ACCESSORY = "Accessory",
        RING      = "Ring",
    }

    local S = {}

    local function emit(name, payload)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, payload) end
    end

    local function ensure(pid)
        local t = S[pid]
        if not t then
            t = { cap = CAP_DEFAULT, items = {}, equip = {} }
            for i=1, t.cap do t.items[i] = nil end
            for i=1, #EQUIP_SLOTS do t.equip[EQUIP_SLOTS[i]] = nil end
            S[pid] = t
        end
        return t
    end

    local function FirstFree(pid)
        local t = ensure(pid)
        for i=1, t.cap do if not t.items[i] then return i end end
        return nil
    end

    function InventoryService.IsFull(pid) return FirstFree(pid) == nil end
    function InventoryService.Capacity(pid) return ensure(pid).cap end
    function InventoryService.List(pid) return ensure(pid).items end
    function InventoryService.GetEquipped(pid)
        local t = ensure(pid); local out = {}
        for k, v in pairs(t.equip) do out[k] = v end
        return out
    end

    local function upper(s)
        if type(s) ~= "string" then return "" end
        local res = ""
        for i=1, string.len(s) do
            local c = string.sub(s, i, i)
            local b = string.byte(c)
            if b >= 97 and b <= 122 then res = res .. string.char(b - 32) else res = res .. c end
        end
        return res
    end

    local function getItemData(itemId)
        local DB = rawget(_G, "ItemDatabase")
        return (DB and DB.GetData) and DB.GetData(itemId) or nil
    end

    local function resolveSlotFromCategories(catOrTbl)
        if type(catOrTbl) == "string" then
            return CATEGORY_TO_SLOT[upper(catOrTbl)]
        elseif type(catOrTbl) == "table" then
            for k, v in pairs(catOrTbl) do
                if type(k) == "string" and v then
                    local s = CATEGORY_TO_SLOT[upper(k)]; if s then return s end
                end
                if type(v) == "string" then
                    local s2 = CATEGORY_TO_SLOT[upper(v)]; if s2 then return s2 end
                end
            end
        end
        return nil
    end

    local function GetSlotForItem(itemId)
        local data = getItemData(itemId); if not data then return nil end
        if data.slot and type(data.slot) == "string" then
            local asUpper = upper(data.slot)
            local mapped = CATEGORY_TO_SLOT[asUpper]
            if mapped then return mapped end
        end
        if data.category then
            local s1 = resolveSlotFromCategories(data.category); if s1 then return s1 end
        end
        if data.categories then
            local s2 = resolveSlotFromCategories(data.categories); if s2 then return s2 end
        end
        return nil
    end

    -- Gates (hero type / power / soul)
    local function getHeroType(pid)
        local PD = rawget(_G, "PlayerData")
        if PD and PD.GetHeroType then local ht = PD.GetHeroType(pid); if ht then return upper(tostring(ht)) end end
        if PD and PD.GetFamily   then local f  = PD.GetFamily(pid);   if f  then return upper(tostring(f )) end end
        return nil
    end
    local function getPowerLevel(pid)
        local PD = rawget(_G, "PlayerData"); if PD and PD.GetPowerLevel then return PD.GetPowerLevel(pid) end
        local P = rawget(_G, "PLAYER_DATA"); if P and P[pid] and type(P[pid].powerLevel)=="number" then return P[pid].powerLevel end
        return 0
    end
    local function getSoulEnergy(pid)
        local PD = rawget(_G, "PlayerData"); if PD and PD.GetSoulEnergy then return PD.GetSoulEnergy(pid) end
        local P = rawget(_G, "PLAYER_DATA"); if P and P[pid] and type(P[pid].soulEnergy)=="number" then return P[pid].soulEnergy end
        return 0
    end
    local function itemAllowsHeroType(data, heroTypeUpper)
        local allowed = rawget(data, "allowedHeroTypes")
        if not allowed then return true end
        if not heroTypeUpper then return false end
        local t = type(allowed)
        if t == "string" then
            return upper(allowed) == heroTypeUpper
        elseif t == "table" then
            for k, v in pairs(allowed) do
                if type(k)=="string" and v==true  and upper(k)==heroTypeUpper then return true end
                if type(v)=="string" and upper(v)==heroTypeUpper then return true end
            end
            return false
        end
        return true
    end
    local function getRequiredNumbers(data)
        local needPower, needSoul = 0, 0
        if type(data.requiredPowerLevel) == "number" then needPower = data.requiredPowerLevel end
        if type(data.requiredSoulEnergy) == "number" then needSoul  = data.requiredSoulEnergy end
        local req = rawget(data, "required")
        if type(req) == "table" then
            if type(req.powerLevel) == "number" then needPower = req.powerLevel end
            if type(req.soulEnergy) == "number" then needSoul  = req.soulEnergy end
        end
        return needPower, needSoul
    end

    local function statApply(pid, slot, itemId)
        local data = getItemData(itemId)
        if not data or not data.stats then return end
        local SS = rawget(_G, "StatSystem")
        if SS and SS.ApplySource then SS.ApplySource(pid, "equip:" .. slot, data.stats) end
    end
    local function statRemove(pid, slot)
        local SS = rawget(_G, "StatSystem")
        if SS and SS.RemoveSource then SS.RemoveSource(pid, "equip:" .. slot) end
    end

    function InventoryService.Add(pid, itemId)
        if type(itemId) ~= "number" then return nil end
        local t = ensure(pid)
        local idx = FirstFree(pid); if not idx then return nil end
        t.items[idx] = itemId
        emit("OnInvItemAdded", { pid = pid, idx = idx, itemId = itemId })
        return idx
    end

    function InventoryService.Remove(pid, idx)
        local t = ensure(pid)
        if not idx or idx < 1 or idx > t.cap then return nil end
        local id = t.items[idx]; t.items[idx] = nil
        if id then emit("OnInvItemRemoved", { pid = pid, idx = idx, itemId = id }) end
        return id
    end

    function InventoryService.Equip(pid, idx)
        local t = ensure(pid)
        if idx < 1 or idx > t.cap then return false end
        local itemId = t.items[idx]; if not itemId then return false end

        local data = getItemData(itemId); if not data then return false end

        local heroType = getHeroType(pid)
        if not itemAllowsHeroType(data, heroType) then
            emit("InvServiceChanged", { pid=pid, action="equip_denied", reason="hero_type", itemId=itemId })
            return false
        end

        local needPower, needSoul = getRequiredNumbers(data)
        local havePower, haveSoul = getPowerLevel(pid), getSoulEnergy(pid)
        if havePower < needPower then
            emit("InvServiceChanged", { pid=pid, action="equip_denied", reason="power", need=needPower, have=havePower, itemId=itemId })
            return false
        end
        if haveSoul < needSoul then
            emit("InvServiceChanged", { pid=pid, action="equip_denied", reason="soul", need=needSoul, have=haveSoul, itemId=itemId })
            return false
        end

        local slot = GetSlotForItem(itemId); if not slot then return false end

        if t.equip[slot] then
            local backIdx = FirstFree(pid); if not backIdx then return false end
            t.items[backIdx] = t.equip[slot]
            emit("OnInvItemAdded", { pid=pid, idx=backIdx, itemId=t.items[backIdx] })
            statRemove(pid, slot)
        end

        t.equip[slot] = itemId
        t.items[idx] = nil
        statApply(pid, slot, itemId)

        emit("OnInvEquipped", { pid=pid, slot=slot, itemId=itemId })
        return true
    end

    function InventoryService.Unequip(pid, slot)
        local t = ensure(pid)
        if type(slot) ~= "string" then return false end
        local itemId = t.equip[slot]
        if not itemId then
            emit("InvServiceChanged", { pid=pid, action="unequip_denied", reason="empty", slot=slot })
            return false
        end
        local free = FirstFree(pid)
        if not free then
            emit("InvServiceChanged", { pid=pid, action="unequip_denied", reason="bag_full", slot=slot, itemId=itemId })
            return false
        end

        statRemove(pid, slot)
        t.items[free] = itemId
        t.equip[slot] = nil

        emit("OnInvUnequipped",  { pid=pid, slot=slot, itemId=itemId, idx=free })
        emit("OnInvItemAdded",   { pid=pid, idx=free, itemId=itemId })
        emit("InvServiceChanged",{ pid=pid, action="unequip", slot=slot, idx=free, itemId=itemId })
        return true
    end

    function InventoryService.ReapplyAll(pid)
        local t = ensure(pid)
        for _, slot in ipairs(EQUIP_SLOTS) do statRemove(pid, slot) end
        for _, slot in ipairs(EQUIP_SLOTS) do local id = t.equip[slot]; if id then statApply(pid, slot, id) end end
    end

    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("InventoryService")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
