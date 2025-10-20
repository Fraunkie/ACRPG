if Debug and Debug.beginFile then Debug.beginFile("ModifierSystem.lua") end
--==================================================
-- ModifierSystem.lua
-- Lightweight modifier manager for units.
-- • Apply(u, key, data) with optional duration
-- • Get(u, key), Has(u, key), Remove(u, key), Clear(u)
-- • Stacks: optional "stacks" number inside data
-- • Auto-expire via timers; cleans up on unit death
-- • Emits ProcBus:
--     - ModifierApplied  { unit, key, data }
--     - ModifierChanged  { unit, key, data }
--     - ModifierRemoved  { unit, key, data, reason = "expire"|"remove"|"clear"|"death" }
--==================================================

if not ModifierSystem then ModifierSystem = {} end
_G.ModifierSystem = ModifierSystem

do
    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- mods[hid] = { [key] = { data = tbl, tmr = timer|nil } }
    local mods = {}
    local function hid(u) return GetHandleId(u) end
    local function valid(u) return u ~= nil and GetUnitTypeId(u) ~= 0 end

    local function emit(name, payload)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, payload) end
    end

    --------------------------------------------------
    -- Internals
    --------------------------------------------------
    local function ensureUnit(u)
        local h = hid(u)
        if not mods[h] then mods[h] = {} end
        return mods[h]
    end

    local function stopTimer(entry)
        if entry and entry.tmr then
            DestroyTimer(entry.tmr)
            entry.tmr = nil
        end
    end

    local function startExpiryTimer(u, key, entry, duration)
        stopTimer(entry)
        if not duration or duration <= 0 then return end
        local t = CreateTimer()
        entry.tmr = t
        TimerStart(t, duration, false, function()
            -- On expiry, remove and announce
            ModifierSystem.Remove(u, key, "expire")
            DestroyTimer(t)
        end)
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    -- Apply or update a modifier.
    -- data may include:
    --   stacks (number), duration (seconds), any custom fields
    --   on_apply(u, key, data), on_change(u, key, data), on_remove(u, key, data, reason)
    function ModifierSystem.Apply(u, key, data)
        if not valid(u) or type(key) ~= "string" then return end
        local per = ensureUnit(u)
        local old = per[key]
        per[key] = per[key] or { data = { stacks = 0 } }
        local entry = per[key]
        entry.data = entry.data or {}

        -- merge shallow
        if type(data) == "table" then
            for k, v in pairs(data) do entry.data[k] = v end
        end
        if entry.data.stacks == nil then entry.data.stacks = 1 end
        if entry.data.stacks < 1 then entry.data.stacks = 1 end

        -- timers
        startExpiryTimer(u, key, entry, entry.data.duration)

        if old == nil and entry.data.on_apply then
            pcall(entry.data.on_apply, u, key, entry.data)
            emit("ModifierApplied", { unit = u, key = key, data = entry.data })
        else
            if entry.data.on_change then pcall(entry.data.on_change, u, key, entry.data) end
            emit("ModifierChanged", { unit = u, key = key, data = entry.data })
        end
    end

    -- Convenience: add stacks and refresh duration if provided
    function ModifierSystem.AddStacks(u, key, add, duration)
        if not valid(u) or type(key) ~= "string" then return end
        local per = ensureUnit(u)
        if not per[key] then
            ModifierSystem.Apply(u, key, { stacks = add or 1, duration = duration })
            return
        end
        local entry = per[key]
        entry.data.stacks = math.max(1, (entry.data.stacks or 1) + (add or 1))
        if duration and duration > 0 then
            entry.data.duration = duration
            startExpiryTimer(u, key, entry, duration)
        end
        if entry.data.on_change then pcall(entry.data.on_change, u, key, entry.data) end
        emit("ModifierChanged", { unit = u, key = key, data = entry.data })
    end

    function ModifierSystem.Get(u, key)
        if not valid(u) or type(key) ~= "string" then return nil end
        local per = mods[hid(u)]; if not per then return nil end
        local entry = per[key]; if not entry then return nil end
        return entry.data
    end

    function ModifierSystem.Has(u, key)
        return ModifierSystem.Get(u, key) ~= nil
    end

    -- Remove a specific modifier
    function ModifierSystem.Remove(u, key, reason)
        if not valid(u) or type(key) ~= "string" then return end
        local h = hid(u)
        local per = mods[h]; if not per then return end
        local entry = per[key]; if not entry then return end
        per[key] = nil

        stopTimer(entry)
        local why = reason or "remove"
        if entry.data and entry.data.on_remove then
            pcall(entry.data.on_remove, u, key, entry.data, why)
        end
        emit("ModifierRemoved", { unit = u, key = key, data = entry.data, reason = why })
    end

    -- Clear all modifiers on a unit
    function ModifierSystem.Clear(u, reason)
        if not valid(u) then return end
        local h = hid(u)
        local per = mods[h]; if not per then return end
        local why = reason or "clear"
        for key, entry in pairs(per) do
            stopTimer(entry)
            if entry.data and entry.data.on_remove then
                pcall(entry.data.on_remove, u, key, entry.data, why)
            end
            emit("ModifierRemoved", { unit = u, key = key, data = entry.data, reason = why })
        end
        mods[h] = nil
    end

    --------------------------------------------------
    -- Death cleanup
    --------------------------------------------------
    OnInit.final(function()
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        end
        TriggerRegisterPlayerUnitEvent(t, Player(PLAYER_NEUTRAL_AGGRESSIVE), EVENT_PLAYER_UNIT_DEATH, nil)
        TriggerAddAction(t, function()
            local u = GetTriggerUnit()
            if valid(u) then
                ModifierSystem.Clear(u, "death")
            end
        end)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ModifierSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
