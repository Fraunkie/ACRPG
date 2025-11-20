if Debug and Debug.beginFile then Debug.beginFile("HFILUnitConfig.lua") end
--==================================================
-- HFILUnitConfig.lua (v0.02)
-- Canonical table for HFIL creeps & minibosses (with spawn gates).
-- Functions:
--   - GetByTypeId(id)                -- Retrieves a row by typeId (numeric or rawcode string).
--   - List()                          -- Returns a list of all entries.
--   - Add(rawStr, data)               -- Adds or overrides a row using a rawcode string.
--   - Disable(rawStr)                 -- Marks a row as inactive.
--   - IsEligible(pid, rowOrTypeId)    -- Checks if a player is eligible for a specific unit (based on power level and soul level).
--   - ListForPlayer(pid)              -- Filters units eligible for a specific player.
--   - PickRandomForPlayer(pid, f)     -- Picks a random eligible unit for the player (with an optional weight function).
--==================================================

if not HFILUnitConfig then HFILUnitConfig = {} end
_G.HFILUnitConfig = HFILUnitConfig

do
    --------------------------------------------------
    -- Source (string rawcodes only, editor-safe)
    --------------------------------------------------
    --------------------------------------------------
    
    
    --------------------------------------------------
    -- HFIL CREEPS
    --------------------------------------------------
    
    local SRC = {
        ["n001"] = {
            baseSoul = 12,
            health   = 200,
            armor    = 5,
            damage   = 10,
            energyResist = 5,
            dodge = 0,
            parry = 0,
            block = 0,
            crit = 1,
            critMult = 1.5,
            isElite  = false,
            abilities = {
                { order = "berserk", castWhenHpBelow = 50, cooldown = 8 },
            },
            minSoulLevel = 1,
            maxSoulLevel = 2,
            active = true,
        },
        ["n00G"] = {
            baseSoul = 20,
            health = 425,
            armor = 8,
            damage = 25,
            energyResist = 5,
            dodge = 10,
            parry = 10,
            block = 10,
            crit = 5,
            critMult = 1.5,
            isElite  = true,
            abilities = {
                { order = "bloodlust", castEvery = 10 },
            },
            minSoulLevel = 3,
            active = true,
        },
        ["n00I"] = {
            baseSoul = 150,
            health = 4000,
            armor = 20,
            damage = 125,
            energyResist = 15,
            dodge = 10,
            parry = 10,
            block = 10,
            crit = 5,
            critMult = 1.5,
            isElite  = true,
            abilities = {
                { order = "bloodlust", castEvery = 10 },
            },
            minSoulLevel = 30,
            active = true,
        },
        ["n00H"] = {
            baseSoul = 150,
            health = 4000,
            armor = 20,
            damage = 125,
            energyResist = 15,
            dodge = 10,
            parry = 10,
            block = 10,
            crit = 5,
            critMult = 1.5,
            isElite  = true,
            abilities = {
                { order = "bloodlust", castEvery = 10 },
            },
            minSoulLevel = 30,
            active = true,
        },
    }

    -- Runtime maps (built after conversion)
    local ROWS_NUM = {}  -- [typeId:number] = row
    local ROWS_STR = {}  -- [rawStr:string]  = row

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    -- GetByTypeId: Retrieves a row by typeId (numeric or rawcode string).
    function HFILUnitConfig.GetByTypeId(id)
        if type(id) == "number" then return ROWS_NUM[id] end
        if type(id) == "string" then
            local r = ROWS_STR[id]; if r then return r end
            if type(FourCC) == "function" then
                local ok, num = pcall(FourCC, id)
                if ok and num then return ROWS_NUM[num] end
            end
        end
        return nil
    end

    -- List: Returns a list of all entries.
    function HFILUnitConfig.List()
        return ROWS_NUM
    end

    -- Add: Adds or overrides a row using a rawcode string.
    function HFILUnitConfig.Add(rawStr, data)
        if type(rawStr) ~= "string" or rawStr == "" then return end
        if type(data) ~= "table" then return end
        SRC[rawStr] = data
    end

    -- Disable: Marks a row as inactive.
    function HFILUnitConfig.Disable(rawStr)
        if type(rawStr) ~= "string" or rawStr == "" then return end
        SRC[rawStr] = SRC[rawStr] or {}
        SRC[rawStr].active = false
    end

    --------------------------------------------------
    -- Eligibility helpers (gates vs PlayerData)
    --------------------------------------------------
    -- _getLevels: Retrieves the player's power level and soul level.
    local function _getLevels(pid)
        local P = rawget(_G, "PlayerData")
        if P and P.Get then
            local pd = P.Get(pid)
            return (pd.powerLevel or 0), (pd.soulLevel or 1)
        end
        return 0, 1
    end

    -- IsEligible: Checks if a player is eligible for a specific unit (based on power level and soul level).
    function HFILUnitConfig.IsEligible(pid, rowOrTypeId)
        local row = rowOrTypeId
        if type(rowOrTypeId) ~= "table" then
            row = HFILUnitConfig.GetByTypeId(rowOrTypeId)
        end
        if not row then return false end

        local pwr, soul = _getLevels(pid)

        if row.minPower      and pwr  < row.minPower      then return false end
        if row.maxPower      and pwr  > row.maxPower      then return false end
        if row.minSoulLevel  and soul < row.minSoulLevel  then return false end
        if row.maxSoulLevel  and soul > row.maxSoulLevel  then return false end

        return true
    end

    -- ListForPlayer: Filters units eligible for a specific player.
    function HFILUnitConfig.ListForPlayer(pid)
        local out = {}
        for typeId, row in pairs(ROWS_NUM) do
            if HFILUnitConfig.IsEligible(pid, row) then
                out[typeId] = row
            end
        end
        return out
    end

    -- PickRandomForPlayer: Picks a random eligible unit for the player (with an optional weight function).
    -- fn(typeId,row) optional weight function; return positive number for weight
    function HFILUnitConfig.PickRandomForPlayer(pid, fn)
        local pool, total = {}, {}
        for typeId, row in pairs(HFILUnitConfig.ListForPlayer(pid)) do
            local w = 1
            if fn then
                local ok, ww = pcall(fn, typeId, row)
                if ok and type(ww) == "number" and ww > 0 then w = ww end
            end
            total = total + w
            pool[#pool+1] = { id = typeId, row = row, w = w }
        end
        if total <= 0 then return nil end
        local r = math.random() * total
        local acc = 0
        for i = 1, #pool do
            acc = acc + pool[i].w
            if r <= acc then return pool[i].id, pool[i].row end
        end
        return pool[#pool].id, pool[#pool].row
    end

    --------------------------------------------------
    -- Internal transforms
    --------------------------------------------------
    -- toOrderId: Converts a string order to an orderId number.
    local function toOrderId(v)
        if type(v) == "number" then return v end
        if type(v) == "string" and v ~= "" and OrderId then
            local ok, num = pcall(OrderId, v)
            if ok and num then return num end
        end
        return 0
    end

    -- deepcopy: Creates a deep copy of a table.
    local function deepcopy(t)
        if type(t) ~= "table" then return t end
        local out = {}
        for k, v in pairs(t) do
            out[k] = (type(v) == "table") and deepcopy(v) or v
        end
        return out
    end

    -- convertOrdersInPlace: Converts order strings in the abilities table to orderId.
    local function convertOrdersInPlace(row)
        if type(row.abilities) == "table" then
            local arr = {}
            for i = 1, #row.abilities do
                local a = row.abilities[i]
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
            row.abilities = arr
        end
    end

    -- applyDefaultsInPlace: Applies default values for missing fields in the row.
    local function applyDefaultsInPlace(row)
        if row.baseSoul == nil then row.baseSoul = 10 end
        if row.isElite  == nil then row.isElite  = false end
        if row.abilities == nil then row.abilities = {} end
        if row.active   == nil then row.active   = true end
    end

    --------------------------------------------------
    -- OnInit: build numeric & string runtime maps
    --------------------------------------------------
    OnInit.final(function()
        ROWS_NUM, ROWS_STR = {}, {}

        for rawStr, data in pairs(SRC) do
            if data ~= nil and data.active ~= false then
                local typeId = 0
                if type(FourCC) == "function" then
                    local ok, num = pcall(FourCC, rawStr)
                    if ok and num then typeId = num end
                end
                if typeId ~= 0 then
                    local row = deepcopy(data)
                    applyDefaultsInPlace(row)
                    convertOrdersInPlace(row)
                    ROWS_NUM[typeId] = row
                    ROWS_STR[rawStr] = row
                end
            end
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("HFILUnitConfig")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
