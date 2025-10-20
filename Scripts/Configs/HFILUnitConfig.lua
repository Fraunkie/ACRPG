if Debug and Debug.beginFile then Debug.beginFile("HFILUnitConfig.lua") end
--==================================================
-- HFILUnitConfig.lua
-- Canonical table for HFIL creeps and minibosses.
-- • Stores data by rawcode string at top level
-- • Converts to numeric keys at OnInit (FourCC safe)
-- • Public API:
--     GetByTypeId(id)
--     List()
--     Add(rawStr, data)
--==================================================

if not HFILUnitConfig then HFILUnitConfig = {} end
_G.HFILUnitConfig = HFILUnitConfig

do
    --------------------------------------------------
    -- Source (string rawcodes only, safe for editor)
    --------------------------------------------------
    local SRC = {
        ["n001"] = {
            baseSoul = 20,
            isElite = false,
            abilities = {
                { order = "berserk",   castWhenHpBelow = 50, cooldown = 8 },
            },
        },
        ["n00G"] = {
            baseSoul = 20,
            isElite = false,
            abilities = {
                { order = "bloodlust", castEvery = 10 },
            },
        },
    }

    -- Runtime map built after FourCC conversion
    local ROWS = {}  -- [typeId] = row

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function HFILUnitConfig.GetByTypeId(id)
        return ROWS[id]
    end

    function HFILUnitConfig.List()
        return ROWS
    end

    -- Add entry by rawcode string; converted later
    function HFILUnitConfig.Add(rawStr, data)
        if type(rawStr) ~= "string" or rawStr == "" then return end
        SRC[rawStr] = data
    end

    --------------------------------------------------
    -- Helpers (safe conversion at init)
    --------------------------------------------------
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

    --------------------------------------------------
    -- OnInit: build numeric keys (safe for natives)
    --------------------------------------------------
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
            InitBroker.SystemReady("HFILUnitConfig")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
