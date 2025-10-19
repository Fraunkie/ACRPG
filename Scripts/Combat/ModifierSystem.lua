if Debug and Debug.beginFile then Debug.beginFile("ModifierSystem.lua") end
--==================================================
-- ModifierSystem.lua
--==================================================
-- Central registry for timed modifiers (buffs/debuffs)
-- Used by: SpellEngine, AscensionSystem, ThreatSystem.
-- Safe (no %), Dev-logged, stackable, fully WC3-compliant.
--==================================================

ModifierSystem = ModifierSystem or {}
_G.ModifierSystem = ModifierSystem

do
    --------------------------------------------------
    -- internal state
    --------------------------------------------------
    local active = {} -- [unitHandle] = { [modName] = {expire=, stacks=, data=} }
    local modDefs = {}

    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function dev()
        return Dev and Dev.IsOn and Dev.IsOn()
    end

    local function log(s)
        if dev() then print("|cff00ffcc[Modifier]|r " .. tostring(s)) end
    end

    --------------------------------------------------
    -- Register new modifier type
    --------------------------------------------------
    -- name: string
    -- data: { duration, maxStacks, onApply, onExpire, onStack }
    function ModifierSystem.Define(name, data)
        if not name or type(data) ~= "table" then return end
        modDefs[name] = data
        log("Registered modifier " .. name)
    end

    --------------------------------------------------
    -- Apply a modifier
    --------------------------------------------------
    function ModifierSystem.Apply(u, name, src)
        if not ValidUnit(u) then return end
        local def = modDefs[name]; if not def then return end

        local hid = GetHandleId(u)
        active[hid] = active[hid] or {}
        local now = active[hid][name]
        local t = TimerStart(CreateTimer(), def.duration or 5.0, false, function()
            ModifierSystem.Remove(u, name)
            DestroyTimer(GetExpiredTimer())
        end)

        if now then
            now.stacks = math.min((now.stacks or 1) + 1, def.maxStacks or 1)
            now.expire = TimerGetElapsed(t) + (def.duration or 5.0)
            if def.onStack then pcall(def.onStack, u, src, now.stacks) end
        else
            active[hid][name] = { expire = TimerGetElapsed(t) + (def.duration or 5.0), stacks = 1, src = src, timer = t }
            if def.onApply then pcall(def.onApply, u, src) end
        end

        log("Applied " .. name .. " to " .. GetUnitName(u))
    end

    --------------------------------------------------
    -- Remove a modifier
    --------------------------------------------------
    function ModifierSystem.Remove(u, name)
        if not ValidUnit(u) then return end
        local hid = GetHandleId(u)
        local mods = active[hid]; if not mods then return end
        local entry = mods[name]; if not entry then return end

        mods[name] = nil
        local def = modDefs[name]
        if def and def.onExpire then pcall(def.onExpire, u, entry.src) end
        log("Removed " .. name .. " from " .. GetUnitName(u))
    end

    --------------------------------------------------
    -- Query
    --------------------------------------------------
    function ModifierSystem.Has(u, name)
        if not ValidUnit(u) then return false end
        local hid = GetHandleId(u)
        return active[hid] and active[hid][name] ~= nil
    end

    function ModifierSystem.GetStacks(u, name)
        if not ValidUnit(u) then return 0 end
        local hid = GetHandleId(u)
        local entry = active[hid] and active[hid][name]
        return (entry and entry.stacks) or 0
    end

    --------------------------------------------------
    -- Clear on death cleanup
    --------------------------------------------------
    OnInit.final(function()
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        end
        TriggerAddAction(t, function()
            local dead = GetTriggerUnit()
            if not ValidUnit(dead) then return end
            local hid = GetHandleId(dead)
            active[hid] = nil
        end)

        log("ModifierSystem ready")
        if InitBroker and InitBroker.SystemReady then
            InitBroker.SystemReady("ModifierSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
