if Debug and Debug.beginFile then Debug.beginFile("DevMode.lua") end
--==================================================
-- DevMode.lua
-- Global and per player developer mode toggles
-- Queried by many systems to gate commands and prints
--==================================================

if not DevMode then DevMode = {} end
_G.DevMode = DevMode

do
    --------------------------------------------------
    -- State
    --------------------------------------------------
    local globalOn = false
    local perPlayer = {}  -- pid -> bool

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function pidOf(p) return GetPlayerId(p) end

    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[DevMode] " .. tostring(s)) end
    end

    -- simple space split without patterns
    local function splitBySpace(s)
        local out = {}
        if not s or s == "" then return out end
        local cur = ""
        for i = 1, string.len(s) do
            local ch = string.sub(s, i, i)
            if ch == " " or ch == "\t" or ch == "\r" or ch == "\n" then
                if cur ~= "" then
                    out[#out + 1] = cur
                    cur = ""
                end
            else
                cur = cur .. ch
            end
        end
        if cur ~= "" then out[#out + 1] = cur end
        return out
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function DevMode.IsEnabled()
        return globalOn == true
    end

    function DevMode.IsOn(pid)
        if perPlayer[pid] ~= nil then
            return perPlayer[pid] == true
        end
        return globalOn == true
    end

    function DevMode.SetEnabled(on)
        globalOn = on and true or false
        dprint("global set to " .. (globalOn and "on" or "off"))
    end

    function DevMode.SetForPlayer(pid, on)
        perPlayer[pid] = on and true or false
        dprint("player " .. tostring(pid) .. " set to " .. (perPlayer[pid] and "on" or "off"))
    end

    --------------------------------------------------
    -- Chat control
    --  -dev on
    --  -dev off
    --  -dev toggle
    --  -dev p N on/off
    --------------------------------------------------
    local function reg(cmd, fn)
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(t, Player(i), cmd, false)
        end
        TriggerAddAction(t, function()
            fn(GetTriggerPlayer(), cmd, GetEventPlayerChatString())
        end)
    end

    reg("-dev", function(who, base, full)
        local pid = pidOf(who)
        local tail = string.sub(full or "", string.len(base) + 2)
        local parts = splitBySpace(tail)
        local a = string.lower(parts[1] or "")
        local b = string.lower(parts[2] or "")
        local c = string.lower(parts[3] or "")

        if a == "on" then
            DevMode.SetEnabled(true)
            DisplayTextToPlayer(who, 0, 0, "Developer mode on")
        elseif a == "off" then
            DevMode.SetEnabled(false)
            DisplayTextToPlayer(who, 0, 0, "Developer mode off")
        elseif a == "toggle" then
            DevMode.SetEnabled(not DevMode.IsEnabled())
            DisplayTextToPlayer(who, 0, 0, "Developer mode toggled")
        elseif a == "p" then
            local which = tonumber(b or "")
            if which ~= nil then
                if c == "on" then
                    DevMode.SetForPlayer(which, true)
                    DisplayTextToPlayer(who, 0, 0, "Developer mode on for player " .. tostring(which))
                elseif c == "off" then
                    DevMode.SetForPlayer(which, false)
                    DisplayTextToPlayer(who, 0, 0, "Developer mode off for player " .. tostring(which))
                else
                    DisplayTextToPlayer(who, 0, 0, "Usage dash dev p N on or off")
                end
            else
                DisplayTextToPlayer(who, 0, 0, "Usage dash dev p N on or off")
            end
        else
            local txt = "Usage dash dev on or off or toggle or p N on or off"
            DisplayTextToPlayer(who, 0, 0, txt)
        end
    end)

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    if OnInit and OnInit.final then
        OnInit.final(function()
            -- default off
        end)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
