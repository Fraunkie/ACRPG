if Debug and Debug.beginFile then Debug.beginFile("ACDebug.lua") end
--==================================================
-- ACDebug.lua
-- Central dev/debug toggle shared by all systems
-- • Provides DevMode.IsOn() and DevMode.Print(tag, msg)
-- • ASCII only, no percent symbols
--==================================================

do
    if not _G.DevMode then _G.DevMode = {} end
    local DM = _G.DevMode

    local DEV_ON = true      -- default enabled for development
    local COLOR_TAG = "|cff88ccff"
    local COLOR_MSG = "|r"

    -- Toggle
    function DM.Toggle()
        DEV_ON = not DEV_ON
        print("[DevMode] " .. (DEV_ON and "Enabled" or "Disabled"))
        return DEV_ON
    end

    function DM.IsOn()
        return DEV_ON
    end

    -- Safe print wrapper
    function DM.Print(tag, msg)
        if not DEV_ON then return end
        print(COLOR_TAG .. "[" .. tostring(tag or "Dev") .. "] " .. COLOR_MSG .. tostring(msg or ""))
    end

    -- Debug-only conditional exec
    function DM.Try(fn)
        if DEV_ON and type(fn) == "function" then
            local ok, err = pcall(fn)
            if not ok then
                print("[DevMode Error] " .. tostring(err))
            end
        end
    end

    OnInit.final(function()
        print("[DevMode] Ready (default on, use -dev to toggle)")
        local trig = CreateTrigger()
        for i = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-dev", true)
        end
        TriggerAddAction(trig, function()
            DM.Toggle()
        end)
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
