if Debug and Debug.beginFile then Debug.beginFile("Core_Sanity.lua") end
--==================================================
-- Core_Sanity.lua
-- Small safety helpers used across systems.
-- • No special characters that upset the editor
-- • Nil safe wrappers for common globals
-- • Adds table.contains if missing
--==================================================

if not CoreUtils then CoreUtils = {} end
_G.CoreUtils = CoreUtils

do
    --------------------------------------------------
    -- Logging and safe call
    --------------------------------------------------
    local function DEV_ON()
        local DM = rawget(_G, "DevMode")
        if DM and type(DM.IsOn) == "function" then
            return DM.IsOn(0) == true
        end
        if DM and type(DM.IsEnabled) == "function" then
            return DM.IsEnabled() == true
        end
        return true
    end

    function CoreUtils.Log(tag, msg)
        if DEV_ON() then
            print("[" .. tostring(tag or "Core") .. "] " .. tostring(msg or ""))
        end
    end

    function CoreUtils.SafeCall(fn, ...)
        if type(fn) ~= "function" then return false, "not a function" end
        local ok, res = pcall(fn, ...)
        if not ok then
            CoreUtils.Log("SafeCall", "error " .. tostring(res))
        end
        return ok, res
    end

    --------------------------------------------------
    -- Table helpers
    --------------------------------------------------
    if not table.contains then
        function table.contains(t, v)
            if type(t) ~= "table" then return false end
            for _, x in pairs(t) do
                if x == v then return true end
            end
            return false
        end
    end

    if not table.shallow_copy then
        function table.shallow_copy(t)
            local out = {}
            if type(t) ~= "table" then return out end
            for k, v in pairs(t) do out[k] = v end
            return out
        end
    end

    --------------------------------------------------
    -- Math helpers
    --------------------------------------------------
    if not math.clamp then
        function math.clamp(v, lo, hi)
            if v < lo then return lo end
            if v > hi then return hi end
            return v
        end
    end

    function CoreUtils.RollPermil(chancePermil)
        local c = tonumber(chancePermil or 0) or 0
        if c <= 0 then return false end
        if c >= 1000 then return true end
        return math.random(1, 1000) <= c
    end

    --------------------------------------------------
    -- Game object helpers
    --------------------------------------------------
    function CoreUtils.ValidUnit(u)
        return u ~= nil and GetUnitTypeId(u) ~= 0
    end

    function CoreUtils.PidOf(u)
        if not u then return nil end
        local p = GetOwningPlayer(u)
        if not p then return nil end
        return GetPlayerId(p)
    end

    function CoreUtils.SafeFourCC(rc)
        if type(FourCC) ~= "function" then return nil end
        local ok, v = pcall(FourCC, rc)
        if ok then return v end
        return nil
    end

    function CoreUtils.SafeGetHero(pid)
        local PD = rawget(_G, "PlayerData")
        if PD and type(PD.Get) == "function" then
            local t = PD.Get(pid)
            if t and CoreUtils.ValidUnit(t.hero) then return t.hero end
        end
        return nil
    end

    -- Bag ignore hook if present
    function CoreUtils.IsBag(u)
        local BS = rawget(_G, "BagSystem")
        if BS and type(BS.IgnoreInCombat) == "function" then
            local ok, res = pcall(BS.IgnoreInCombat, u)
            if ok then return res == true end
        end
        return false
    end

    --------------------------------------------------
    -- ProcBus helpers
    --------------------------------------------------
    function CoreUtils.Emit(name, payload)
        local PB = rawget(_G, "ProcBus")
        if PB and type(PB.Emit) == "function" then
            CoreUtils.SafeCall(PB.Emit, name, payload)
        end
    end

    function CoreUtils.On(name, fn)
        local PB = rawget(_G, "ProcBus")
        if PB and type(PB.On) == "function" then
            return PB.On(name, fn)
        end
        return nil
    end

    --------------------------------------------------
    -- Chat registration helper (only if not present)
    --------------------------------------------------
    if not _G.ChatTriggers then _G.ChatTriggers = {} end
    if not CoreUtils.RegisterChat then
        function CoreUtils.RegisterChat(cmd, handler)
            if not cmd or cmd == "" or type(handler) ~= "function" then return end
            if ChatTriggers[cmd] then return end
            local trig = CreateTrigger()
            ChatTriggers[cmd] = trig
            for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
                TriggerRegisterPlayerChatEvent(trig, Player(i), cmd, false)
            end
            TriggerAddAction(trig, function()
                local p   = GetTriggerPlayer()
                local msg = GetEventPlayerChatString()
                CoreUtils.SafeCall(handler, p, cmd, msg)
            end)
        end
    end

    --------------------------------------------------
    -- Timer helper
    --------------------------------------------------
    function CoreUtils.After(delay, fn)
        local t = CreateTimer()
        TimerStart(t, delay, false, function()
            CoreUtils.SafeCall(fn)
            DestroyTimer(t)
        end)
        return t
    end

    --------------------------------------------------
    -- Init banner
    --------------------------------------------------
    OnInit.final(function()
        CoreUtils.Log("Core_Sanity", "ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("Core_Sanity")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
