if Debug and Debug.beginFile then Debug.beginFile("HFIL_UnitConfig.lua") end
--==================================================
-- HFIL_UnitConfig.lua
-- Canonical per-unit config for HFIL creeps.
-- Safe for World Editor (FourCC only in OnInit.final)
--==================================================

if not HFILUnitConfig then HFILUnitConfig = {} end
_G.HFILUnitConfig = HFILUnitConfig

do
    --------------------------------------------------
    -- Defaults
    --------------------------------------------------
    local DEFAULTS = {
        baseSoul = 10,
        scales = true,
        scaleMult = 1.10,
        share = true,
        powerGate = 20000,
        shardChancePermil = 0,
        fragChancePermil  = 0,
        statDrop = { chancePermil = 0, stat = "agi", min = 1, max = 1 },
        tags = {},
        abilities = {},
    }

    local TAG_MULT = {
        elite = 1.20,
        mini_boss = 1.40,
        boss = 1.75,
    }

    --------------------------------------------------
    -- Static data (strings only)
    --------------------------------------------------
    local CREEPS = {
        { id="n001", name="Wandering Spirit", baseSoul=10 },
        { id="n00N", name="Lost Echo",        baseSoul=12 },
        { id="n00M", name="Lost Shade",       baseSoul=14 },

        -- Test creep for spell AI
        { id="n00G", name="Vengeful Wraith",
          baseSoul=20, scaleMult=1.12, tags={"elite"},
          abilities={
              -- Example: buff itself under 70 HP percent
              { orderId=852662, target="self",   castWhenHpBelow=70, cooldown=8 },
              -- Example: target the threat leader every 10 sec
              { orderId=852095, target="leader", castEvery=10,        cooldown=10 }
          }
        },

        { id="n00L", name="Tormented Spirit",      baseSoul=22, tags={"elite"} },
        { id="n00J", name="Fallen Soul Collector", baseSoul=30, tags={"elite"} },
        { id="n00K", name="Soul Enforcer",         baseSoul=40, tags={"elite"} },
        { id="n00H", name="HFIL Guardian",         baseSoul=70, tags={"mini_boss"} },
        { id="n007", name="Goz (Unstable)",        baseSoul=55, tags={"elite"} },
        { id="n00I", name="Mez (Unstable)",        baseSoul=55, tags={"elite"} },
        { id="n000", name="Test Dummy",            baseSoul=0,  scales=false, share=false },
    }

    --------------------------------------------------
    -- Runtime lookups
    --------------------------------------------------
    local byId = {}
    local byFour = {}

    local function applyDefaults(row)
        for k, v in pairs(DEFAULTS) do
            if row[k] == nil then
                if type(v) == "table" then
                    local copy = {}
                    for kk, vv in pairs(v) do copy[kk] = vv end
                    row[k] = copy
                else
                    row[k] = v
                end
            end
        end
        return row
    end

    local function rebuildStringLookup()
        byId = {}
        for i = 1, #CREEPS do
            local row = CREEPS[i]
            if row.id then
                byId[row.id] = applyDefaults(row)
            end
        end
    end

    local function rebuildFourLookup()
        byFour = {}
        for id, row in pairs(byId) do
            local ok, num = pcall(FourCC, id)
            if ok and num then
                byFour[num] = row
            end
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function HFILUnitConfig.GetByTypeId(raw)
        if type(raw) == "string" then return byId[raw] end
        if type(raw) == "number" then return byFour[raw] end
        return nil
    end

    function HFILUnitConfig.TagMultiplier(tags)
        if not tags then return 1.0 end
        local m = 1.0
        for i = 1, #tags do
            local k = TAG_MULT[tags[i]]
            if k then m = m * k end
        end
        return m
    end

    function HFILUnitConfig.List()
        return CREEPS, DEFAULTS, TAG_MULT
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        rebuildStringLookup()
        rebuildFourLookup()
        print("[HFIL_UnitConfig] ready (" .. tostring(#CREEPS) .. " creeps)")
        local IB = rawget(_G, "InitBroker")
        if IB and type(IB.SystemReady) == "function" then
            IB.SystemReady("HFIL_UnitConfig")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
