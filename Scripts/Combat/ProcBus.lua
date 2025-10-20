if Debug and Debug.beginFile then Debug.beginFile("ProcBus.lua") end
--==================================================
-- ProcBus.lua (re-entrancy safe)
-- Global event bus (On, Once, Emit) with per-event
-- re-entrancy guard and a small deferred queue.
--==================================================

if not ProcBus then ProcBus = {} end
_G.ProcBus = ProcBus

do
    local listeners = {}   -- name -> {fn1, fn2, ...}
    local onceList  = {}   -- name -> {fn1, fn2, ...}

    -- Re-entrancy / deferral
    local emitting  = {}   -- name -> true while emitting
    local pending   = {}   -- name -> { {payload}, ... } queued while emitting
    local MAX_FLUSH = 64   -- safety cap to avoid pathological loops

    local function _deliver_one(name, payload)
        local list = listeners[name]
        if list then
            for _, fn in ipairs(list) do
                local ok, err = pcall(fn, payload)
                if not ok then
                    print("[ProcBus] " .. tostring(name) .. " handler error: " .. tostring(err))
                end
            end
        end
        local once = onceList[name]
        if once then
            onceList[name] = nil
            for _, fn in ipairs(once) do
                local ok, err = pcall(fn, payload)
                if not ok then
                    print("[ProcBus] once " .. tostring(name) .. " error: " .. tostring(err))
                end
            end
        end
    end

    function ProcBus.Emit(name, payload)
        if not name then return end

        -- If we're already in Emit(name), queue and return.
        if emitting[name] then
            pending[name] = pending[name] or {}
            pending[name][#pending[name] + 1] = payload
            return
        end

        emitting[name] = true
        _deliver_one(name, payload)

        -- Flush any queued payloads for the same event (bounded)
        local flushes = 0
        while pending[name] and #pending[name] > 0 and flushes < MAX_FLUSH do
            local p = table.remove(pending[name], 1)
            _deliver_one(name, p)
            flushes = flushes + 1
        end
        pending[name] = nil
        emitting[name] = nil
    end

    function ProcBus.On(name, fn)
        if not name or type(fn) ~= "function" then return end
        listeners[name] = listeners[name] or {}
        listeners[name][#listeners[name] + 1] = fn
    end

    function ProcBus.Once(name, fn)
        if not name or type(fn) ~= "function" then return end
        onceList[name] = onceList[name] or {}
        onceList[name][#onceList[name] + 1] = fn
    end

    OnInit.final(function()
        print("[ProcBus] ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ProcBus")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
