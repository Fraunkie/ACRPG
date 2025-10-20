if Debug and Debug.beginFile then Debug.beginFile("CreepRespawnSystem.lua") end
--==================================================
-- CreepRespawnSystem.lua
-- Minimal neutral creep respawn manager.
-- • Define spawn points and respawn time
-- • Emits ProcBus "CREEP_SPAWN" and "CREEP_DEATH"
-- • Calls ThreatSystem.OnCreepSpawn / OnCreepDeath
-- • Accepts string raw ids or numeric FourCC
--==================================================

if not CreepRespawnSystem then CreepRespawnSystem = {} end
_G.CreepRespawnSystem = CreepRespawnSystem

do
    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local NEUTRAL = Player(PLAYER_NEUTRAL_AGGRESSIVE)

    local function ValidUnit(u) return u ~= nil and GetUnitTypeId(u) ~= 0 end
    local function toFour(raw)
        if type(raw) == "number" then return raw end
        if type(raw) == "string" then
            local ok, num = pcall(FourCC, raw)
            if ok and num then return num end
        end
        return 0
    end

    local function dprint(s)
        local DM = rawget(_G, "DevMode")
        if DM and DM.IsOn and DM.IsOn(0) then print("[Respawn] " .. tostring(s)) end
    end

    local function PB() return rawget(_G, "ProcBus") end
    local function emit(name, e)
        local bus = PB()
        if bus and bus.Emit then bus.Emit(name, e) end
    end

    local function TS() return rawget(_G, "ThreatSystem") end
    local function TS_OnSpawn(u, isElite, packId)
        local t = TS(); if not t then return end
        if t.OnCreepSpawn then pcall(t.OnCreepSpawn, u, isElite, packId)
        elseif t.Register then pcall(t.Register, u) end
    end
    local function TS_OnDeath(u)
        local t = TS(); if not t then return end
        if t.OnCreepDeath then pcall(t.OnCreepDeath, u)
        elseif t.ClearUnit then pcall(t.ClearUnit, u) end
    end

    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- row fields: id, raw, x, y, face, owner, isElite, packId, respawnSec, onSpawn
    local SPAWNS  = {}    -- id -> row
    local BY_UNIT = {}    -- handle -> row
    local timers  = {}    -- id -> timer

    --------------------------------------------------
    -- Spawning
    --------------------------------------------------
    local function doSpawn(row)
        if not row then return nil end
        local owner = row.owner or NEUTRAL
        local raw   = toFour(row.raw)
        if raw == 0 then dprint("bad raw for spawn " .. tostring(row.id)); return nil end

        local u = CreateUnit(owner, raw, row.x or 0, row.y or 0, row.face or 270)
        if not ValidUnit(u) then return nil end

        BY_UNIT[GetHandleId(u)] = row

        if row.onSpawn and type(row.onSpawn) == "function" then
            pcall(row.onSpawn, u, row)
        end

        TS_OnSpawn(u, row.isElite == true, row.packId)
        emit("CREEP_SPAWN", { unit = u, isElite = row.isElite == true, packId = row.packId, id = row.id })

        dprint("spawned " .. tostring(row.id))
        return u
    end

    local function scheduleRespawn(row)
        if not row then return end
        local sec = tonumber(row.respawnSec or 10) or 10
        if sec <= 0 then return end
        local old = timers[row.id]; if old then DestroyTimer(old); timers[row.id] = nil end

        local t = CreateTimer(); timers[row.id] = t
        TimerStart(t, sec, false, function()
            timers[row.id] = nil
            doSpawn(row)
            DestroyTimer(t)
        end)
        dprint("scheduled " .. tostring(row.id) .. " in " .. tostring(sec) .. " sec")
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function CreepRespawnSystem.AddSpawn(args)
        if not args or not args.id then return end
        SPAWNS[args.id] = {
            id = args.id,
            raw = args.raw,
            x = args.x, y = args.y,
            face = args.face or 270,
            owner = args.owner or NEUTRAL,
            isElite = args.isElite == true,
            packId = args.packId,
            respawnSec = tonumber(args.respawnSec or 10) or 10,
            onSpawn = args.onSpawn
        }
        dprint("added spawn " .. tostring(args.id))
        return SPAWNS[args.id]
    end

    function CreepRespawnSystem.SpawnNow(id)
        local row = SPAWNS[id]; if not row then return nil end
        return doSpawn(row)
    end

    function CreepRespawnSystem.OnDeath(u)
        if not ValidUnit(u) then return end
        local h = GetHandleId(u)
        local row = BY_UNIT[h]; if not row then return end
        BY_UNIT[h] = nil
        TS_OnDeath(u)
        emit("CREEP_DEATH", { unit = u, id = row.id })
        scheduleRespawn(row)
    end

    function CreepRespawnSystem.OnSpawn(u, isElite, packId)
        if not ValidUnit(u) then return end
        local raw = GetUnitTypeId(u)
        for _, row in pairs(SPAWNS) do
            if toFour(row.raw) == raw then
                BY_UNIT[GetHandleId(u)] = row
                row.isElite = isElite == true or row.isElite == true
                row.packId = packId or row.packId
                break
            end
        end
        TS_OnSpawn(u, isElite == true, packId)
        local r = BY_UNIT[GetHandleId(u)]
        emit("CREEP_SPAWN", { unit = u, isElite = isElite == true, packId = packId, id = r and r.id or nil })
    end

    function CreepRespawnSystem.GetRowByUnit(u)
        if not ValidUnit(u) then return nil end
        return BY_UNIT[GetHandleId(u)]
    end

    function CreepRespawnSystem.List()
        return SPAWNS
    end

    --------------------------------------------------
    -- Death wiring
    --------------------------------------------------
    OnInit.final(function()
        local tk = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(tk, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        end
        TriggerRegisterPlayerUnitEvent(tk, NEUTRAL, EVENT_PLAYER_UNIT_DEATH, nil)

        TriggerAddAction(tk, function()
            local dead = GetTriggerUnit()
            if not ValidUnit(dead) then return end
            if BY_UNIT[GetHandleId(dead)] then
                CreepRespawnSystem.OnDeath(dead)
            end
        end)

        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CreepRespawnSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
