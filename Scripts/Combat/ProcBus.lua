if Debug and Debug.beginFile then Debug.beginFile("ProcBus.lua") end
--==================================================
-- ProcBus.lua
-- Central lightweight event bus
-- • Supports Emit / On / Once
-- • Safe for multiplayer and nil-safe
--==================================================

do
    if not _G.ProcBus then _G.ProcBus = {} end
    local PB = _G.ProcBus

    --------------------------------------------------
    -- Internal state
    --------------------------------------------------
    local listeners = {}   -- name -> { fn, fn, ... }
    local onceList  = {}   -- name -> { fn, fn, ... }
    local firing    = {}   -- stack protection

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[ProcBus] " .. tostring(s)) end
    end

    --------------------------------------------------
    -- Register a persistent listener
    --------------------------------------------------
    function PB.On(name, fn)
        if type(name) ~= "string" or type(fn) ~= "function" then return end
        listeners[name] = listeners[name] or {}
        table.insert(listeners[name], fn)
        dprint("On " .. name .. " (" .. tostring(#listeners[name]) .. " total)")
    end

    --------------------------------------------------
    -- Register a one-time listener
    --------------------------------------------------
    function PB.Once(name, fn)
        if type(name) ~= "string" or type(fn) ~= "function" then return end
        onceList[name] = onceList[name] or {}
        table.insert(onceList[name], fn)
        dprint("Once " .. name)
    end

    --------------------------------------------------
    -- Emit an event (safe for all)
    --------------------------------------------------
    function PB.Emit(name, data)
        if firing[name] then
            dprint("Skipping nested emit for " .. name)
            return
        end
        firing[name] = true

        local ok, err = pcall(function()
            -- persistent listeners
            local list = listeners[name]
            if list then
                for i = 1, #list do
                    local fn = list[i]
                    if type(fn) == "function" then
                        local ok2, err2 = pcall(fn, data)
                        if not ok2 then
                            dprint("Listener error (" .. name .. "): " .. tostring(err2))
                        end
                    end
                end
            end

            -- one-time listeners
            local once = onceList[name]
            if once then
                for i = 1, #once do
                    local fn = once[i]
                    if type(fn) == "function" then
                        local ok3, err3 = pcall(fn, data)
                        if not ok3 then
                            dprint("Once listener error (" .. name .. "): " .. tostring(err3))
                        end
                    end
                end
                onceList[name] = nil
            end
        end)

        if not ok then
            dprint("Emit error for " .. name .. ": " .. tostring(err))
        end
        firing[name] = false
    end

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
