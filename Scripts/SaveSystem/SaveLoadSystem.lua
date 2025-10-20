if Debug and Debug.beginFile then Debug.beginFile("SaveLoadSystem.lua") end
--==================================================
-- SaveLoadSystem.lua
-- Versioned snapshot + pluggable backends.
-- Default backend: Preload files on disk (SaveIO_Preloader).
-- Supports per-player slots: p<id>_slot<idx>.pld
--
-- CLEAR EXTENSION POINTS (search "ADD HERE"):
--  • BuildSnapshot: add new fields to save
--  • ApplySnapshot: restore those fields
--  • Register(name, export, import): systems attach their own data
--==================================================

if not SaveLoadSystem then SaveLoadSystem = {} end
_G.SaveLoadSystem = SaveLoadSystem

do
    local SCHEMA_VERSION = 1
    local SAVE_EPOCH     = 1     -- bump to invalidate old saves on disk
    local SAVE_SALT      = "AC1" -- for future code-based saves
    local BASE_DIR       = "Animecraft"
    local DEFAULT_SLOTS  = 6

    --------------------------------------------------
    -- Small safe codec (no quotes or backslashes)
    --------------------------------------------------
    local Codec = {}

    local function enc(v)
        if v == nil then return "" end
        local t = type(v)
        if t == "number" then
            if v ~= v then return "0" end
            return tostring(math.floor(v + 0.0))
        elseif t == "boolean" then
            return v and "1" or "0"
        elseif t == "string" then
            local s = string.gsub(v, "[^%w%._%-]", "_")
            return s
        elseif t == "table" then
            local out, n = {}, 0
            for i = 1, #v do
                out[#out+1] = enc(v[i])
                n = n + 1
            end
            if n > 0 then return table.concat(out, ",") end
            local parts = {}
            for k, val in pairs(v) do
                parts[#parts+1] = enc(k) .. ":" .. enc(val)
            end
            return table.concat(parts, ",")
        end
        return ""
    end

    local function decNum(s)
        local n = tonumber(s or "0")
        if not n then return 0 end
        return math.floor(n + 0.0)
    end

    local function split(str, sep)
        local out = {}
        if not str or str == "" then return out end
        local pattern = "([^" .. sep .. "]+)"
        for token in string.gmatch(str, pattern) do
            out[#out+1] = token
        end
        return out
    end

    function Codec.pack(tbl)
        local parts = {}
        local function add(k, v) parts[#parts+1] = enc(k) .. "=" .. enc(v) end

        add("__ver", SCHEMA_VERSION)
        add("epoch", SAVE_EPOCH)
        add("heroType", tbl.heroType or 0)
        add("zone", tbl.zone or "YEMMA")
        add("soulEnergy", tbl.soulEnergy or 0)
        add("soulLevel", tbl.soulLevel or 1)
        add("soulXP", tbl.soulXP or 0)
        add("powerLevel", tbl.powerLevel or 0)

        local s = tbl.stats or {}
        add("stats", { s.power or 0, s.defense or 0, s.speed or 0, s.crit or 0 })

        local c = tbl.combat or {}
        add("combat", {
            c.armor or 0, c.energyResist or 0, c.dodge or 0, c.parry or 0,
            c.block or 0, c.critChance or 0, math.floor((c.critMult or 1.5) * 1000)
        })

        add("fragments", tbl.fragments or 0)
        -- ADD HERE: extra top-level PlayerData fields you want to persist
        -- add("introDone", tbl.introCompleted and 1 or 0)

        return table.concat(parts, ";")
    end

    function Codec.unpack(text)
        local snap = { stats = {}, combat = {} }
        if not text or text == "" then return snap end
        local pairsList = split(text, ";")
        for i = 1, #pairsList do
            local kv = pairsList[i]
            local eq = string.find(kv, "=", 1, true)
            if eq then
                local k = string.sub(kv, 1, eq - 1)
                local v = string.sub(kv, eq + 1)
                if k == "__ver" then
                    snap.__ver = decNum(v)
                elseif k == "epoch" then
                    snap.epoch = decNum(v)
                elseif k == "heroType" then snap.heroType = decNum(v)
                elseif k == "zone" then snap.zone = v
                elseif k == "soulEnergy" then snap.soulEnergy = decNum(v)
                elseif k == "soulLevel" then snap.soulLevel = decNum(v)
                elseif k == "soulXP" then snap.soulXP = decNum(v)
                elseif k == "powerLevel" then snap.powerLevel = decNum(v)
                elseif k == "stats" then
                    local a = split(v, ",")
                    snap.stats = {
                        power  = decNum(a[1] or "0"),
                        defense= decNum(a[2] or "0"),
                        speed  = decNum(a[3] or "0"),
                        crit   = decNum(a[4] or "0"),
                    }
                elseif k == "combat" then
                    local a = split(v, ",")
                    snap.combat = {
                        armor        = decNum(a[1] or "0"),
                        energyResist = decNum(a[2] or "0"),
                        dodge        = decNum(a[3] or "0"),
                        parry        = decNum(a[4] or "0"),
                        block        = decNum(a[5] or "0"),
                        critChance   = decNum(a[6] or "0"),
                        critMult     = (decNum(a[7] or "1500") / 1000.0),
                    }
                elseif k == "fragments" then
                    snap.fragments = decNum(v)
                -- ADD HERE: parse your extra fields
                end
            end
        end
        return snap
    end

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function toUnitId(v)
        if type(v) == "number" then return v end
        if type(v) == "string" then
            local ok, id = pcall(FourCC, v)
            if ok and id and id ~= 0 then return id end
        end
        return FourCC("H001")
    end

    local function readSpawnXY()
        if GameBalance then
            if GameBalance.SPAWN then return GameBalance.SPAWN.x or 0, GameBalance.SPAWN.y or 0 end
            if GameBalance.START_NODES and GameBalance.START_NODES.SPAWN then
                return GameBalance.START_NODES.SPAWN.x or 0, GameBalance.START_NODES.SPAWN.y or 0
            end
            if GameBalance.HUB_COORDS and GameBalance.HUB_COORDS.SPAWN then
                return GameBalance.HUB_COORDS.SPAWN.x or 0, GameBalance.HUB_COORDS.SPAWN.y or 0
            end
        end
        return 0, 0
    end

    local function PD(pid)
        if _G.PlayerData and PlayerData.Get then return PlayerData.Get(pid) end
        PLAYER_DATA = PLAYER_DATA or {}
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end

    --------------------------------------------------
    -- Backend: Preload on disk
    --------------------------------------------------
    local function slotName(pid, slot)  -- p0_slot1
        return "p" .. tostring(pid) .. "_slot" .. tostring(slot or 1)
    end

    local backend = {
        name = "preload",
        save = function(pid, slot, snap)
            if not SaveIO or not SaveIO.Write then return false end
            local text = Codec.pack(snap)
            return SaveIO.Write(BASE_DIR, slotName(pid, slot), text)
        end,
        load = function(pid, slot)
            if not SaveIO or not SaveIO.Read then return nil, "no_backend" end
            local text = SaveIO.Read(BASE_DIR, slotName(pid, slot))
            if not text or text == "" then return nil, "not_found" end
            return Codec.unpack(text), nil
        end
    }

    function SaveLoadSystem.SetBackend(b) backend = b or backend end

    --------------------------------------------------
    -- Module registry (future)
    --------------------------------------------------
    local modules = {}
    function SaveLoadSystem.Register(name, exporterFn, importerFn)
        if not name or name == "" then return end
        modules[name] = { export = exporterFn, import = importerFn }
    end

    --------------------------------------------------
    -- Snapshot build/apply
    --------------------------------------------------
    function SaveLoadSystem.BuildSnapshot(pid, pd)
        pd = pd or PD(pid)
        local snap = {
            __ver      = SCHEMA_VERSION,
            heroType   = (pd.hero and ValidUnit(pd.hero)) and GetUnitTypeId(pd.hero) or (GameBalance and GameBalance.START_HERO_ID) or FourCC("H001"),
            zone       = pd.zone or "YEMMA",
            soulEnergy = pd.soulEnergy or 0,
            soulLevel  = pd.soulLevel  or 1,
            soulXP     = pd.soulXP     or 0,
            powerLevel = pd.powerLevel or 0,
            stats  = pd.stats  or { power=0, defense=0, speed=0, crit=0 },
            combat = pd.combat or { armor=0, energyResist=0, dodge=0, parry=0, block=0, critChance=0, critMult=1.5 },
            fragments   = pd.fragments   or 0,
            ownedShards = pd.ownedShards or {},
            teleports   = pd.teleports   or {},
            modules     = {},
            extras      = {}, -- ADD HERE: other PlayerData fields
        }

        -- ADD HERE: top-level fields (e.g. introCompleted)
        -- snap.introCompleted = pd.introCompleted and 1 or 0

        for name, obj in pairs(modules) do
            if obj.export then
                local ok, data = pcall(obj.export, pid, pd)
                if ok and data ~= nil then snap.modules[name] = data end
            end
        end
        return snap
    end

    function SaveLoadSystem.ApplySnapshot(pid, snap)
        if not snap then return false, "nil_snapshot" end
        local p  = Player(pid)
        local pd = PD(pid)

        local unitId = toUnitId(snap.heroType or (GameBalance and GameBalance.START_HERO_ID) or "H001")
        local x, y = readSpawnXY()
        local hero = CreateUnit(p, unitId, x, y, 270.0)
        pd.hero = hero
        if _G.PlayerHero then PlayerHero[pid] = hero end

        pd.zone       = snap.zone or pd.zone or "YEMMA"
        pd.soulEnergy = snap.soulEnergy or 0
        pd.soulLevel  = snap.soulLevel  or 1
        pd.soulXP     = snap.soulXP     or 0
        pd.powerLevel = snap.powerLevel or 0

        if _G.PlayerData and PlayerData.SetStats then
            PlayerData.SetStats(pid, snap.stats)
        else
            pd.stats = snap.stats or pd.stats
        end
        if _G.PlayerData and PlayerData.SetCombat then
            PlayerData.SetCombat(pid, snap.combat)
        else
            pd.combat = snap.combat or pd.combat
        end

        pd.fragments   = snap.fragments   or 0
        pd.ownedShards = snap.ownedShards or {}
        pd.teleports   = snap.teleports   or {}

        -- ADD HERE: apply extra fields
        -- pd.introCompleted = (snap.introCompleted == 1)

        for name, obj in pairs(modules) do
            if obj.import and snap.modules and snap.modules[name] then
                pcall(obj.import, pid, pd, snap.modules[name])
            end
        end

        if GetLocalPlayer() == p then
            PanCameraToTimed(x, y, 0.30)
            ClearSelection()
            if hero and GetUnitTypeId(hero) ~= 0 then SelectUnit(hero, true) end
        end

        if ProcBus and ProcBus.Emit then
            ProcBus.Emit("OnHeroCreated", { pid = pid, unit = hero })
        end
        return true, nil
    end

    --------------------------------------------------
    -- Public Save / Load (with epoch gate)
    --------------------------------------------------
    function SaveLoadSystem.Save(pid, pd, slot)
        pd = pd or PD(pid)
        local snap = SaveLoadSystem.BuildSnapshot(pid, pd)
        local ok = backend.save(pid, slot or 1, snap)
        return ok and true or false, ok and nil or "backend_save_error"
    end

    function SaveLoadSystem.Load(pid, slot)
        local snap, err = backend.load(pid, slot or 1)
        if not snap then return false, err or "not_found" end

        if (snap.epoch or 0) ~= SAVE_EPOCH then
            return false, "epoch_mismatch"
        end

        local ok, aerr = SaveLoadSystem.ApplySnapshot(pid, snap)
        return ok, aerr
    end

    --------------------------------------------------
    -- Helpers for wipes and epoch
    --------------------------------------------------
    function SaveLoadSystem.GetEpoch()
        return SAVE_EPOCH
    end

    function SaveLoadSystem.SetEpoch(n)
        if type(n) == "number" and n >= 0 then
            SAVE_EPOCH = math.floor(n + 0.0)
        end
    end

    function SaveLoadSystem.WipeAll(pid, slots)
        local count = slots or DEFAULT_SLOTS
        for i = 1, count do
            if SaveIO and SaveIO.Write then
                SaveIO.Write(BASE_DIR, "p" .. tostring(pid) .. "_slot" .. tostring(i), "")
            end
        end
    end

    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SaveLoadSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
