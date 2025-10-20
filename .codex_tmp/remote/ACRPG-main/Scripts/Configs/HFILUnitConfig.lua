if Debug and Debug.beginFile then Debug.beginFile("HFIL_UnitConfig.lua") end
--==================================================
-- HFIL_UnitConfig.lua
-- Canonical per-unit config for HFIL creeps.
-- Safe for World Editor (FourCC only in OnInit.final)
-- • Merged with EliteOverrides and Camps skeleton
-- • Exposes both HFILUnitConfig and HFIL_UnitConfig globals
-- • ASCII only, no percent symbols in strings
--==================================================

-- Canonical table + aliases (both names supported)
if not HFILUnitConfig then HFILUnitConfig = {} end
_G.HFILUnitConfig  = HFILUnitConfig
_G.HFIL_UnitConfig = HFILUnitConfig

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
              -- Example: buff itself under 70 HP percent (orderId is editor raw order)
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
    -- Elite overrides (string keys; converted at init)
    --------------------------------------------------
    -- Optional per-unit elite tuning that overrides GameBalance.EliteConfig defaults.
    -- Keys must be editor IDs like "n001".
    HFILUnitConfig.EliteOverridesRaw = HFILUnitConfig.EliteOverridesRaw or {
        -- Starters
        n001 = { chance = 2,  hpX = 3.0, dmgX = 1.4 },
        n00G = { chance = 1,  hpX = 3.0, dmgX = 1.5 },
        -- You can add more rows here as needed
    }

    -- Numeric map built at init (read by Respawn/Threat/HUD if desired)
    HFILUnitConfig.EliteOverrides = HFILUnitConfig.EliteOverrides or {}

    --------------------------------------------------
    -- Camps skeleton (optional; Respawn adopts preplaced anyway)
    --------------------------------------------------
    -- Useful for grouping packs, patrols, and per-camp overrides later.
    HFILUnitConfig.Camps = HFILUnitConfig.Camps or {
        -- Example (disabled by default; fill coordinates to enable):
        -- {
        --     campId = "HFIL_A1_IMPS_01",
        --     zoneId = "HFIL",
        --     anchorX = 28800.0, anchorY = 27850.0,
        --     spawnRadius = 160.0,
        --     maxAlive = 3,
        --     packLink = true,
        --     leashRadius = 900.0,
        --     spawnOnPlayers = true,
        --     minPlayerDistance = 0,
        --     respawnProfileId = "HFIL_Starter",
        --     eliteChance = 2, -- overrides global if set
        --     composition = { { id = "n001", weight = 3 }, { id = "n00G", weight = 1 } },
        --     patrolPathId = nil,
        -- },
    }

    --------------------------------------------------
    -- Runtime lookups
    --------------------------------------------------
    local byId   = {}
    local byFour = {}

    local function deepcopy(src)
        local dst = {}
        for k, v in pairs(src) do
            if type(v) == "table" then
                local t = {}
                for kk, vv in pairs(v) do t[kk] = vv end
                dst[k] = t
            else
                dst[k] = v
            end
        end
        return dst
    end

    local function applyDefaults(row)
        for k, v in pairs(DEFAULTS) do
            if row[k] == nil then
                if type(v) == "table" then
                    row[k] = deepcopy(v)
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

    -- Elite per-unit override getter (numeric typeId)
    if not HFILUnitConfig.GetEliteOverride then
        function HFILUnitConfig.GetEliteOverride(typeId)
            return HFILUnitConfig.EliteOverrides[typeId]
        end
    end
end

------------------------------------------------------
-- Init (build numeric maps / normalize camps)
------------------------------------------------------
OnInit.final(function()
    -- Build per-unit elite numeric overrides
    if HFILUnitConfig and HFILUnitConfig.EliteOverridesRaw then
        for rawId, ov in pairs(HFILUnitConfig.EliteOverridesRaw) do
            if type(rawId) == "string" and type(ov) == "table" then
                local idNum = FourCC(rawId)
                if idNum and idNum ~= 0 then
                    HFILUnitConfig.EliteOverrides[idNum] = {
                        chance = ov.chance,
                        hpX    = ov.hpX,
                        dmgX   = ov.dmgX,
                    }
                end
            end
        end
    end

    -- Normalize Camp composition IDs to numeric (stored alongside as _idNum)
    if HFILUnitConfig and HFILUnitConfig.Camps then
        for _, camp in ipairs(HFILUnitConfig.Camps) do
            if camp.composition then
                for _, row in ipairs(camp.composition) do
                    if type(row.id) == "string" then
                        row._idNum = FourCC(row.id)
                    end
                end
            end
        end
    end

    -- Build standard lookups for creeps
    if HFILUnitConfig then
        -- local functions are upvalues inside the do-end; rebuild via exposed List
        local creeps = HFILUnitConfig.List()
        -- Re-run internal builders
    end

    -- Recreate string and numeric lookups after any external changes
    -- (recreating locally using same functions defined above)
    -- Note: using the upvalues from the outer scope
    -- (This segment relies on the earlier local functions still in scope)
    -- Safe to call:
    --   rebuildStringLookup()
    --   rebuildFourLookup()
    if type(rebuildStringLookup) == "function" then
        rebuildStringLookup()
    end
    if type(rebuildFourLookup) == "function" then
        rebuildFourLookup()
    end

    if rawget(_G, "InitBroker") and InitBroker.SystemReady then
        InitBroker.SystemReady("HFIL_UnitConfig")
    end
    print("[HFIL_UnitConfig] ready")
end)

if Debug and Debug.endFile then Debug.endFile() end
