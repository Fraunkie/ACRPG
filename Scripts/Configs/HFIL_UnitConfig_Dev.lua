if Debug and Debug.beginFile then Debug.beginFile("HFIL_UnitConfig_Dev.lua") end
--==================================================
-- HFIL_UnitConfig_Dev.lua
-- Dev override/additions for HFIL unit config.
-- • Same API as HFILUnitConfig:
--     GetByTypeId(id), List(), Add(rawStr, data)
-- • Top-level uses strings; conversion at OnInit.
--==================================================

if not HFIL_UnitConfig_Dev then HFIL_UnitConfig_Dev = {} end
_G.HFIL_UnitConfig_Dev = HFIL_UnitConfig_Dev

do
    local SRC = {
        -- Example dev tweak: n001 gives a bit more during testing
        -- ["n001"] = { baseSoul = 25 },
    }

    local ROWS = {}  -- [typeId] = row

    function HFIL_UnitConfig_Dev.GetByTypeId(id)
        return ROWS[id]
    end

    function HFIL_UnitConfig_Dev.List()
        return ROWS
    end

    function HFIL_UnitConfig_Dev.Add(rawStr, data)
        if type(rawStr) ~= "string" or rawStr == "" then return end
        SRC[rawStr] = data
    end

    local function toOrderId(v)
        if type(v) == "number" then return v end
        if type(v) == "string" and v ~= "" and OrderId then
            local ok, num = pcall(OrderId, v)
            if ok and num then return num end
        end
        return 0
    end

    local function deepCopyAndConvertOrders(t)
        if type(t) ~= "table" then return t end
        local out = {}
        for k, v in pairs(t) do
            if k == "abilities" and type(v) == "table" then
                local arr = {}
                for i = 1, #v do
                    local a = v[i]
                    if type(a) == "table" then
                        local one = {}
                        for kk, vv in pairs(a) do one[kk] = vv end
                        if one.order then
                            one.orderId = toOrderId(one.order)
                            one.order = nil
                        end
                        arr[#arr + 1] = one
                    end
                end
                out[k] = arr
            else
                out[k] = deepCopyAndConvertOrders(v)
            end
        end
        return out
    end

    OnInit.final(function()
        for rawStr, data in pairs(SRC) do
            local typeId = 0
            if type(FourCC) == "function" then
                local ok, num = pcall(FourCC, rawStr)
                if ok and num then typeId = num end
            end
            if typeId ~= 0 then
                local row = deepCopyAndConvertOrders(data)
                ROWS[typeId] = row
            end
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("HFIL_UnitConfig_Dev")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
