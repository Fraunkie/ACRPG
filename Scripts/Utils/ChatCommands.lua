if Debug and Debug.beginFile then Debug.beginFile("ChatCommands.lua") end
--==================================================
-- ChatTriggerRegistry.lua
-- Centralized, editor-safe chat command registry.
-- All test/dev commands unified here (DevMode gated).
--==================================================

if not ChatTriggers then ChatTriggers = {} end
_G.ChatTriggers = ChatTriggers

do
    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function devOn(pid)
        local DM = rawget(_G, "DevMode")
        if DM then
            if type(DM.IsOn) == "function" then return DM.IsOn(pid) end
            if type(DM.IsEnabled) == "function" then return DM.IsEnabled() end
        end
        return true
    end

    local function registerChat(cmd, fn)
        if not cmd or cmd == "" or type(fn) ~= "function" then return end
        if ChatTriggers[cmd] then return end

        local t = CreateTrigger()
        ChatTriggers[cmd] = t
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(t, Player(i), cmd, false)
        end
        TriggerAddAction(t, function()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            if not devOn(pid) then return end
            local msg = GetEventPlayerChatString()
            local ok, err = pcall(fn, p, pid, msg)
            if not ok then
                DisplayTextToPlayer(p, 0, 0, "[Chat Error] " .. tostring(err))
            end
        end)
    end

    local function parseNum(msg, cmd)
        local s = string.sub(msg, string.len(cmd) + 2)
        local num = tonumber(s) or 0
        print("Parsed number: " .. tostring(num))
        return num
    end

    local function getSelectedUnitSafe(p)
        local u = GetTriggerUnit()
        if u and GetUnitTypeId(u) ~= 0 then return u end
        if SelectUnitForPlayerSingle then
            local g = CreateGroup()
            GroupEnumUnitsSelected(g, p, nil)
            local first = FirstOfGroup(g)
            DestroyGroup(g)
            if first and GetUnitTypeId(first) ~= 0 then return first end
        end
        return nil
    end

    --------------------------------------------------
    -- Debug / DevMode
    --------------------------------------------------
    registerChat("-dev", function(p)
        if _G.DevMode and DevMode.Toggle then DevMode.Toggle() end
        DisplayTextToPlayer(p, 0, 0, "[DevMode] toggled")
    end)

    registerChat("-initdump", function(p)
        if _G.InitBroker and InitBroker.Dump then InitBroker.Dump() end
    end)

    registerChat("-watchdog", function(p)
        local t = CreateTimer()
        local n = 0
        TimerStart(t, 1.0, true, function()
            n = n + 1
            DisplayTextToPlayer(p, 0, 0, "[wd] tick " .. tostring(n))
            if n >= 10 then DestroyTimer(t) end
        end)
    end)

    --------------------------------------------------
    -- Soul Energy
    --------------------------------------------------
    registerChat("-soul", function(p, pid)
        if _G.SoulEnergy then
            local getXp = (SoulEnergy.GetXp or SoulEnergy.Get)
            local xp = getXp and getXp(pid) or 0
            DisplayTextToPlayer(p, 0, 0, "Soul energy: " .. tostring(xp))
        end
    end)

    registerChat("-souls", function(p, pid)
        if _G.SoulEnergy then
            local getXp = (SoulEnergy.GetXp or SoulEnergy.Get)
            local xp  = getXp and getXp(pid) or 0
            local lvl = (SoulEnergy.GetLevel and SoulEnergy.GetLevel(pid)) or 1
            DisplayTextToPlayer(p, 0, 0,
                "Soul XP: " .. tostring(xp) .. "  |  Soul Level: " .. tostring(lvl))
        end
    end)

    registerChat("-souladd", function(p, pid, msg)
        if _G.SoulEnergy then
            local n = parseNum(msg, "-souladd")
            local addFn = SoulEnergy.AddXp or SoulEnergy.Add
            local v = addFn and addFn(pid, n) or 0
            DisplayTextToPlayer(p, 0, 0, "Soul energy now " .. tostring(v))
        end
    end)

    registerChat("-soulset", function(p, pid, msg)
        if _G.SoulEnergy then
            local n = parseNum(msg, "-soulset")
            local setFn = SoulEnergy.SetXp or SoulEnergy.Set
            local v = setFn and setFn(pid, n) or 0
            DisplayTextToPlayer(p, 0, 0, "Soul energy set to " .. tostring(v))
        end
    end)

    --------------------------------------------------
    -- Spirit Drive
    --------------------------------------------------
    registerChat("-sd", function(p, pid, msg)
        local n = parseNum(msg, "-sd")
        if _G.SpiritDrive and SpiritDrive.Set then
            SpiritDrive.Set(pid, n)
            local v, m = SpiritDrive.Get(pid)
            DisplayTextToPlayer(p, 0, 0, "Spirit Drive " .. tostring(v) .. "/" .. tostring(m))
        end
    end)

    registerChat("-sdadd", function(p, pid, msg)
        local n = parseNum(msg, "-sdadd")
        if _G.SpiritDrive and SpiritDrive.Add then
            SpiritDrive.Add(pid, n)
            local v, m = SpiritDrive.Get(pid)
            DisplayTextToPlayer(p, 0, 0, "Spirit Drive " .. tostring(v) .. "/" .. tostring(m))
        end
    end)

    --------------------------------------------------
    -- Save System Commands
    --------------------------------------------------
    registerChat("-save", function(p, pid)
        if _G.SaveLoadSystem and SaveLoadSystem.Save then
            SaveLoadSystem.Save(pid)
        end
    end)

    registerChat("-load", function(p, pid)
        if _G.SaveLoadSystem and SaveLoadSystem.Load then
            SaveLoadSystem.Load(pid)
        end
    end)

    --------------------------------------------------
    -- Combat Debug Commands
    --------------------------------------------------
    registerChat("-dmg", function(p, pid, msg)
        local n = parseNum(msg, "-dmg")
        local target = getSelectedUnitSafe(p)
        if target and _G.DamageEngine then
            DamageEngine.UnitDamageTarget(PlayerHero[pid], target, n, true)
        end
    end)

    --------------------------------------------------
    -- Threat System Debug
    --------------------------------------------------
    registerChat("-threat", function(p, pid)
        if _G.ThreatSystem and ThreatSystem.DebugThreat then
            local target = getSelectedUnitSafe(p)
            if target then
                ThreatSystem.DebugThreat(target)
            end
        end
    end)

    --------------------------------------------------
    -- Spirit System Debug
    --------------------------------------------------
    registerChat("-sp", function(p, pid, msg)
        if _G.SpiritDrive then
            local n = parseNum(msg, "-sp")
            DisplayTextToPlayer(p, 0, 0, "Spirit Power: " .. n)
        end
    end)

    --------------------------------------------------
    -- Console Debug Commands
    --------------------------------------------------
    registerChat(".", function(p, pid, msg)
        if _G.IngameConsole and IngameConsole.HandleCommand then
            IngameConsole.HandleCommand(pid, msg)
        end
    end)

    registerChat("-debug", function(p, pid)
        if _G.DebugUtils and DebugUtils.ToggleDebug then
            DebugUtils.ToggleDebug(pid)
        end
    end)

    --------------------------------------------------
    -- Stats System Debug
    --------------------------------------------------
    registerChat("-stats", function(p, pid)
        if _G.HeroStatSystem and HeroStatSystem.DebugStats then
            local hero = PlayerData.GetHero(pid)
            if hero then
                HeroStatSystem.DebugStats(hero)
            end
        end
    end)

    --------------------------------------------------
    -- Init marker
    --------------------------------------------------
    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ChatTriggerRegistry")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
