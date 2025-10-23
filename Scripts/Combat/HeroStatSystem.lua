if Debug and Debug.beginFile then Debug.beginFile("HeroStatSystem.lua") end
--==================================================
-- HeroStatSystem.lua
-- Lightweight per-hero stats store.
-- • BindHero(pid, hero)
-- • Get(hero, key) -> number
-- • Set(hero, key, value)
-- • Add(hero, key, delta)
-- • GetAll(hero) -> table (read-only copy)
-- Emits ProcBus:
--   - HeroStatsChanged { unit=hero, key=key, value=value, delta=delta or 0 }
-- Notes:
--   - WC3 editor safe; no top-level natives
--   - UPDATED: integrates with StatSystem + InventoryService on bind/death
--==================================================

if not HeroStatSystem then HeroStatSystem = {} end
_G.HeroStatSystem = HeroStatSystem

do
    --------------------------------------------------
    -- State
    --------------------------------------------------
    local STATS = {}   -- STATS[hid] = { key = number, ... }
    local OWNER = {}   -- OWNER[hid] = pid

    local function hid(u) return GetHandleId(u) end
    local function valid(u) return u ~= nil and GetUnitTypeId(u) ~= 0 end

    local function emitChanged(u, key, value, delta)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then
            PB.Emit("HeroStatsChanged", { unit = u, key = key, value = value, delta = delta or 0 })
        end
    end

    local function ensure(u)
        local h = hid(u)
        if not STATS[h] then
            STATS[h] = {
                power = 0, defense = 0, speed = 0, crit = 0,
                hpRegen = 0, mpRegen = 0,
            }
        end
        return STATS[h]
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function HeroStatSystem.BindHero(pid, hero)
        if not valid(hero) then return end
        OWNER[hid(hero)] = pid
        ensure(hero)

        -- Keep PlayerData in sync
        if _G.PlayerData and PlayerData.SetHero then
            PlayerData.SetHero(pid, hero)
        end

        -- Push any already-queued item sources now that we have a concrete unit
        if _G.StatSystem and StatSystem.Recompute then
            StatSystem.Recompute(pid)
        end

        -- Reapply equip effects in case hero instance changed/swapped
        if _G.InventoryService and InventoryService.ReapplyAll then
            InventoryService.ReapplyAll(pid)
        end
    end

    function HeroStatSystem.Get(u, key)
        if not valid(u) or type(key) ~= "string" then return 0 end
        local t = STATS[hid(u)]; if not t then return 0 end
        local v = t[key]
        if type(v) ~= "number" then return 0 end
        return v
    end

    function HeroStatSystem.Set(u, key, value)
        if not valid(u) or type(key) ~= "string" then return end
        local t = ensure(u)
        local old = tonumber(t[key] or 0) or 0
        local v = tonumber(value or 0) or 0
        t[key] = v
        emitChanged(u, key, v, v - old)
    end

    function HeroStatSystem.Add(u, key, delta)
        if not valid(u) or type(key) ~= "string" then return end
        local t = ensure(u)
        local old = tonumber(t[key] or 0) or 0
        local d = tonumber(delta or 0) or 0
        if d == 0 then return end
        local v = old + d
        t[key] = v
        emitChanged(u, key, v, d)
    end

    function HeroStatSystem.GetAll(u)
        if not valid(u) then return {} end
        local src = STATS[hid(u)]; if not src then return {} end
        local out = {}
        for k, v in pairs(src) do out[k] = v end
        return out
    end

    function HeroStatSystem.AddMany(u, tbl)
        if not valid(u) or type(tbl) ~= "table" then return end
        for k, v in pairs(tbl) do
            if type(v) == "number" then HeroStatSystem.Add(u, k, v) end
        end
    end

    function HeroStatSystem.ClearKey(u, key)
        if not valid(u) or type(key) ~= "string" then return end
        local t = STATS[hid(u)]; if not t then return end
        local old = t[key]
        if old ~= nil then
            t[key] = nil
            emitChanged(u, key, 0, - (tonumber(old or 0) or 0))
        end
    end

    --------------------------------------------------
    -- Cleanup on death
    --------------------------------------------------
    local function onDeath()
        local u = GetTriggerUnit()
        if not valid(u) then return end
        local h = hid(u)
        local pid = OWNER[h]

        STATS[h] = nil
        OWNER[h] = nil

        -- Zero out applied item totals for that pid
        if _G.StatSystem and StatSystem.Recompute and type(pid) == "number" then
            StatSystem.Recompute(pid)
        end
    end

    OnInit.final(function()
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        end
        TriggerAddAction(t, onDeath)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("HeroStatSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
