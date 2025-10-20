if Debug and Debug.beginFile then Debug.beginFile("ModifierSystem.lua") end
--==================================================
-- ModifierSystem.lua
-- Central registry for timed modifiers (buffs/debuffs).
-- Used by: SpellEngine, AscensionSystem, ThreatSystem.
--==================================================

ModifierSystem = ModifierSystem or {}
_G.ModifierSystem = ModifierSystem

do
    local active  = {} -- [unitHandle] = { [name] = {timer=, expire=, stacks=, src=} }
    local modDefs = {}

    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function dev() return Debug and Debug.printf end
    local function log(s) if dev() then Debug.printf("[Modifier] " .. tostring(s)) end end

    -- Define a modifier type: { duration, maxStacks, onApply, onExpire, onStack }
    function ModifierSystem.Define(name, data)
        if not name or type(data) ~= "table" then return end
        modDefs[name] = data
        log("Registered " .. name)
    end

    -- Apply or stack a modifier
    function ModifierSystem.Apply(u, name, src)
        if not ValidUnit(u) then return end
        local def = modDefs[name]; if not def then return end
        local hid = GetHandleId(u)
        active[hid] = active[hid] or {}
        local entry = active[hid][name]

        if entry then
            entry.stacks = math.min((entry.stacks or 1) + 1, def.maxStacks or 1)
            if entry.timer then PauseTimer(entry.timer); DestroyTimer(entry.timer) end
        else
            entry = { stacks = 1, src = src }
            active[hid][name] = entry
            if def.onApply then pcall(def.onApply, u, src) end
        end

        entry.timer = CreateTimer()
        local dur = def.duration or 5.0
        entry.expire = dur
        TimerStart(entry.timer, dur, false, function()
            ModifierSystem.Remove(u, name)
            DestroyTimer(GetExpiredTimer())
        end)

        if def.onStack and entry.stacks > 1 then pcall(def.onStack, u, src, entry.stacks) end
        log("Applied " .. name .. " to " .. GetUnitName(u) .. " (" .. tostring(entry.stacks) .. ")")
    end

    -- Remove a modifier immediately
    function ModifierSystem.Remove(u, name)
        if not ValidUnit(u) then return end
        local hid = GetHandleId(u)
        local mods = active[hid]; if not mods then return end
        local entry = mods[name]; if not entry then return end
        if entry.timer then PauseTimer(entry.timer); DestroyTimer(entry.timer) end
        mods[name] = nil
        local def = modDefs[name]
        if def and def.onExpire then pcall(def.onExpire, u, entry.src) end
        log("Removed " .. name .. " from " .. GetUnitName(u))
    end

    -- Queries
    function ModifierSystem.Has(u, name)
        if not ValidUnit(u) then return false end
        local hid = GetHandleId(u); return active[hid] and active[hid][name] ~= nil
    end
    function ModifierSystem.GetStacks(u, name)
        if not ValidUnit(u) then return 0 end
        local hid = GetHandleId(u); local e = active[hid] and active[hid][name]
        return (e and e.stacks) or 0
    end

    -- Cleanup on death
    OnInit.final(function()
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        end
        TriggerAddAction(t, function()
            local dead = GetTriggerUnit(); if not ValidUnit(dead) then return end
            local hid = GetHandleId(dead)
            local mods = active[hid]
            if mods then
                for name, e in pairs(mods) do
                    if e.timer then PauseTimer(e.timer); DestroyTimer(e.timer) end
                    local def = modDefs[name]
                    if def and def.onExpire then pcall(def.onExpire, dead, e.src) end
                end
            end
            active[hid] = nil
        end)

        if InitBroker and InitBroker.SystemReady then InitBroker.SystemReady("ModifierSystem") end
        log("ready")
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
