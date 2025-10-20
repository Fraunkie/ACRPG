if Debug and Debug.beginFile then Debug.beginFile("InitBroker.lua") end
--==================================================
-- InitBroker.lua
-- Simple readiness broker (SystemReady / WaitFor)
--==================================================

if not InitBroker then InitBroker = {} end
_G.InitBroker = InitBroker

do
    local ready   = {}
    local waiting = {}

    function InitBroker.SystemReady(name)
        if not name or ready[name] then return end
        ready[name] = true
        if waiting[name] then
            for _, fn in ipairs(waiting[name]) do pcall(fn) end
            waiting[name] = nil
        end
        print("[InitBroker] " .. tostring(name) .. " ready")
    end

    function InitBroker.WaitFor(name, fn)
        if not name or type(fn) ~= "function" then return end
        if ready[name] then pcall(fn) else
            waiting[name] = waiting[name] or {}
            table.insert(waiting[name], fn)
        end
    end

    function InitBroker.IsReady(name)
        return ready[name] == true
    end

    OnInit.final(function()
        print("[InitBroker] initialized")
        InitBroker.SystemReady("InitBroker")
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
