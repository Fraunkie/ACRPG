if Debug and Debug.beginFile then Debug.beginFile("ProcBus.lua") end
--==================================================
-- ProcBus.lua
-- Central lightweight event bus
-- • Supports On / Once / Emit
-- • Adds aliases: Subscribe, SubscribeOnce, Publish
-- • Adds Off (remove one fn) and Clear (remove all)
-- • Safe for multiplayer and nil-safe
--==================================================

do
    if not _G.ProcBus then _G.ProcBus = {} end
    local PB = _G.ProcBus

    --------------------------------------------------
    -- Internal state
    --------------------------------------------------
    local listeners = listeners or {}   -- name -> { fn, fn, ... }
    local onceList  = onceList  or {}   -- name -> { fn, fn, ... }
    local firing    = firing    or {}   -- stack protection

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[ProcBus] " .. tostring(s)) end
    end

    local function add(tbl, name, fn)
        if type(name) ~= "string" or type(fn) ~= "function" then return end
        tbl[name] = tbl[name] or {}
        table.insert(tbl[name], fn)
    end

    local function removeOne(tbl, name, fn)
        local list = tbl[name]
        if not list then return end
        for i = #list, 1, -1 do
            if list[i] == fn then
                table.remove(list, i)
                if #list == 0 then tbl[name] = nil end
                return
            end
        end
    end

    --------------------------------------------------
    -- Register a persistent listener
    --------------------------------------------------
    function PB.On(name, fn)
        add(listeners, name, fn)
        dprint("On " .. name .. " (" .. tostring(#listeners[name]) .. " total)")
    end

    --------------------------------------------------
    -- Register a one-time listener
    --------------------------------------------------
    function PB.Once(name, fn)
        add(onceList, name, fn)
        dprint("Once " .. name)
    end

    --------------------------------------------------
    -- Remove a single listener (persistent or once)
    --------------------------------------------------
    function PB.Off(name, fn)
        if type(name) ~= "string" or type(fn) ~= "function" then return end
        removeOne(listeners, name, fn)
        removeOne(onceList,  name, fn)
    end

    --------------------------------------------------
    -- Clear all listeners for an event name
    --------------------------------------------------
    function PB.Clear(name)
        if type(name) ~= "string" then return end
        listeners[name] = nil
        onceList[name]  = nil
        dprint("Cleared " .. name)
    end

    --------------------------------------------------
    -- Emit an event (safe for all)
    --------------------------------------------------
    function PB.Emit(name, data)
        if type(name) ~= "string" then return end
        if firing[name] then
            dprint("Skipping nested emit for " .. name)
            return
        end
        firing[name] = true

        local ok, err = pcall(function()
            -- persistent listeners
            local list = listeners[name]
            if list then
                -- copy to prevent mutation during iteration
                local copy = {}
                for i = 1, #list do copy[i] = list[i] end
                for i = 1, #copy do
                    local fn = copy[i]
                    if type(fn) == "function" then
                        local ok2, err2 = pcall(fn, data)
                        if not ok2 then dprint("Listener error (" .. name .. "): " .. tostring(err2)) end
                    end
                end
            end
            -- one-time listeners
            local once = onceList[name]
            if once then
                onceList[name] = nil
                for i = 1, #once do
                    local fn = once[i]
                    if type(fn) == "function" then
                        local ok3, err3 = pcall(fn, data)
                        if not ok3 then dprint("Once listener error (" .. name .. "): " .. tostring(err3)) end
                    end
                end
            end
        end)

        if not ok then dprint("Emit error for " .. name .. ": " .. tostring(err)) end
        firing[name] = false
    end

    --------------------------------------------------
    -- Aliases (compat with older/newer code)
    --------------------------------------------------
    PB.Subscribe      = PB.On
    PB.SubscribeOnce  = PB.Once
    PB.Publish        = PB.Emit

    --------------------------------------------------
    -- Debug dump
    --------------------------------------------------
    function PB.Dump()
        dprint("Listeners:")
        for name, list in pairs(listeners) do
            dprint("  " .. name .. " (" .. tostring(#list) .. ")")
        end
        dprint("Once:")
        for name, list in pairs(onceList) do
            dprint("  " .. name .. " (" .. tostring(#list) .. ")")
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        dprint("ready (event bus online)")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ProcBus")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
