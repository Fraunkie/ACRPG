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
        return tonumber(s) or 0
    end

    local function getSelectedUnitSafe(p)
        if BlzGetUnitWithOrderTarget and false then end
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
            local v = SoulEnergy.Get and SoulEnergy.Get(pid) or 0
            DisplayTextToPlayer(p, 0, 0, "Soul energy: " .. tostring(v))
        end
    end)

    registerChat("-souladd", function(p, pid, msg)
        if _G.SoulEnergy then
            local n = parseNum(msg, "-souladd")
            local v = SoulEnergy.Add and SoulEnergy.Add(pid, n) or 0
            DisplayTextToPlayer(p, 0, 0, "Soul energy now " .. tostring(v))
        end
    end)

    registerChat("-soulset", function(p, pid, msg)
        if _G.SoulEnergy then
            local n = parseNum(msg, "-soulset")
            local v = SoulEnergy.Set and SoulEnergy.Set(pid, n) or 0
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
    -- Lives System
    --------------------------------------------------
    registerChat("-life", function(p, pid, msg)
        local n = parseNum(msg, "-life")
        if _G.LivesSystem and LivesSystem.Set then
            LivesSystem.Set(pid, n)
            local v, m = LivesSystem.Get(pid)
            DisplayTextToPlayer(p, 0, 0, "Lives " .. tostring(v) .. "/" .. tostring(m))
        end
    end)

    registerChat("-lifeadd", function(p, pid, msg)
        local n = parseNum(msg, "-lifeadd")
        if _G.LivesSystem and LivesSystem.Add then
            LivesSystem.Add(pid, n)
            local v, m = LivesSystem.Get(pid)
            DisplayTextToPlayer(p, 0, 0, "Lives " .. tostring(v) .. "/" .. tostring(m))
        end
    end)

    --------------------------------------------------
    -- Teleport + Hero utility
    --------------------------------------------------
    registerChat("-tpui", function(p, pid)
        if _G.TeleportShop and TeleportShop.Show then
            TeleportShop.Show(pid)
        end
    end)

    registerChat("-tp ", function(p, pid, msg)
        local node = string.sub(msg, string.len("-tp ") + 1)
        if node and node ~= "" and _G.TeleportSystem then
            TeleportSystem.Unlock(pid, node)
            TeleportSystem.TeleportToNode(pid, node, { reason = "dev_tp" })
        else
            DisplayTextToPlayer(p, 0, 0, "Usage: -tp NODE_ID")
        end
    end)

    -- Moved from legacy Dev_commands: bind selected unit as hero
    registerChat("-sethero", function(p, pid)
        local u = getSelectedUnitSafe(p)
        if u and GetUnitTypeId(u) ~= 0 then
            if _G.PlayerData and PlayerData.SetHero then
                PlayerData.SetHero(pid, u)
            else
                PLAYER_DATA = PLAYER_DATA or {}
                PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
                PLAYER_DATA[pid].hero = u
                _G.PlayerHero = _G.PlayerHero or {}
                _G.PlayerHero[pid] = u
            end
            DisplayTextToPlayer(p, 0, 0, "Hero bound")
        else
            DisplayTextToPlayer(p, 0, 0, "Select a unit first, then use -sethero")
        end
    end)

    -- Moved from legacy Dev_commands: where am I
    registerChat("-where", function(p, pid)
        local u = (_G.PlayerData and PlayerData.GetHero and PlayerData.GetHero(pid))
                  or (PLAYER_DATA and PLAYER_DATA[pid] and PLAYER_DATA[pid].hero)
        if u and GetUnitTypeId(u) ~= 0 then
            local x, y = GetUnitX(u), GetUnitY(u)
            DisplayTextToPlayer(p, 0, 0, "X " .. string.format("%.1f", x) .. " Y " .. string.format("%.1f", y))
        else
            DisplayTextToPlayer(p, 0, 0, "No hero bound. Use -sethero")
        end
    end)

    --------------------------------------------------
    -- Threat HUD
    --------------------------------------------------
    registerChat("-thud", function(p)
        local pid = GetPlayerId(p)
        if _G.CombatThreatHUD and CombatThreatHUD.Toggle then
            CombatThreatHUD.Toggle(pid)
            local shown = CombatThreatHUD.visible and CombatThreatHUD.visible[pid]
            if shown then
                DisplayTextToPlayer(p, 0, 0, "Threat HUD on")
            else
                DisplayTextToPlayer(p, 0, 0, "Threat HUD off")
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
