if Debug and Debug.beginFile then Debug.beginFile("InitBroker.lua") end
--==================================================
-- InitBroker.lua
-- Tiny readiness tracker so systems can announce "ready"
-- and other code can poll or wait safely.
-- • Nil-safe, ASCII only
-- • DEV-gated prints only
--==================================================

do
    if not _G.InitBroker then _G.InitBroker = {} end
    local IB = _G.InitBroker

    local ready = {}      -- name -> true
    local waiters = {}    -- name -> { fn, fn, ... }

    local function DEV_ON()
        return (rawget(_G, "DevMode") and type(DevMode.IsOn) == "function" and DevMode.IsOn()) or false
    end
    local function dprint(msg) if DEV_ON() then print("[Init] " .. tostring(msg)) end end

    -- Mark a system as ready
    function IB.SystemReady(name)
        if type(name) ~= "string" or name == "" then return end
        if ready[name] then return end
        ready[name] = true
        dprint("ready: " .. name)

        local list = waiters[name]
        if list then
            for i = 1, #list do
                local fn = list[i]
                if type(fn) == "function" then
                    local ok, err = pcall(fn)
                    if not ok then dprint("waiter error for " .. name .. " -> " .. tostring(err)) end
                end
            end
            waiters[name] = nil
        end
    end

    -- Check if a system is ready
    function IB.IsReady(name)
        return ready[name] == true
    end

    -- Run a callback once the system is ready (immediate if already ready)
    function IB.WhenReady(name, fn)
        if type(name) ~= "string" or type(fn) ~= "function" then return false end
        if ready[name] then
            local ok, err = pcall(fn)
            if not ok then dprint("WhenReady immediate error for " .. name .. " -> " .. tostring(err)) end
            return true
        end
        local list = waiters[name]
        if not list then
            list = {}
            waiters[name] = list
        end
        table.insert(list, fn)
        return true
    end

    -- Debug helper
    function IB.Dump()
        print("[Init] Ready systems:")
        for k,v in pairs(ready) do if v then print(" - " .. k) end end
        print("[Init] Pending waiters:")
        for k,list in pairs(waiters) do print(" - " .. k .. " (" .. tostring(#list) .. " callbacks)") end
    end

    OnInit.final(function()
        dprint("InitBroker online")
        IB.SystemReady("InitBroker")
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
