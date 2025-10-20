if Debug and Debug.beginFile then Debug.beginFile("ChatTriggerRegistry.lua") end
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

    local function parseName(msg, cmd)
        -- returns the substring after "<cmd> " trimmed of leading spaces
        local s = string.sub(msg, string.len(cmd) + 2)
        -- trim leading spaces
        local i = 1
        while string.sub(s, i, i) == " " do i = i + 1 end
        return string.sub(s, i)
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
    -- Respawn / Elite / Slot (CreepRespawnSystem)
    --------------------------------------------------
    registerChat("-respawn debug", function(p, pid)
        if not _G.CreepRespawnSystem or not CreepRespawnSystem.ToggleDebug then
            DisplayTextToPlayer(p, 0, 0, "[Respawn] System not found")
            return
        end
        CreepRespawnSystem.ToggleDebug()
        DisplayTextToPlayer(p, 0, 0, "[Respawn] Debug toggled")
    end)

    registerChat("-respawn now", function(p, pid, msg)
        if not _G.CreepRespawnSystem or not CreepRespawnSystem.RespawnNow then
            DisplayTextToPlayer(p, 0, 0, "[Respawn] System not found")
            return
        end
        local n = parseNum(msg, "-respawn now")
        if n <= 0 then
            DisplayTextToPlayer(p, 0, 0, "Usage: -respawn now N")
            return
        end
        CreepRespawnSystem.RespawnNow(n, false)
        DisplayTextToPlayer(p, 0, 0, "[Respawn] Forced respawn slot " .. tostring(n))
    end)

    registerChat("-elite now", function(p, pid, msg)
        if not _G.CreepRespawnSystem or not CreepRespawnSystem.RespawnNow then
            DisplayTextToPlayer(p, 0, 0, "[Respawn] System not found")
            return
        end
        local n = parseNum(msg, "-elite now")
        if n <= 0 then
            DisplayTextToPlayer(p, 0, 0, "Usage: -elite now N")
            return
        end
        CreepRespawnSystem.RespawnNow(n, true)
        DisplayTextToPlayer(p, 0, 0, "[Respawn] Forced ELITE respawn slot " .. tostring(n))
    end)

    registerChat("-slot info", function(p, pid, msg)
        local n = parseNum(msg, "-slot info")
        if n <= 0 then
            DisplayTextToPlayer(p, 0, 0, "Usage: -slot info N")
            return
        end
        local shown = false
        if _G.CreepRespawnSystem and CreepRespawnSystem._DebugGetSlot then
            local s = CreepRespawnSystem._DebugGetSlot(n)
            if s then
                DisplayTextToPlayer(p, 0, 0, "[Slot] id " .. tostring(s.id) ..
                    " x " .. tostring(math.floor(s.x)) ..
                    " y " .. tostring(math.floor(s.y)) ..
                    " face " .. tostring(math.floor(s.facing)))
                shown = true
            end
        end
        if not shown then
            DisplayTextToPlayer(p, 0, 0, "[Slot] Info not available")
        end
    end)

    --------------------------------------------------
    -- Respawn Profile switcher (RespawnProfileSwitcher.lua)
    --------------------------------------------------
    registerChat("-profile list", function(p, pid)
        if not _G.GameBalance or not GameBalance.RespawnProfiles then
            DisplayTextToPlayer(p, 0, 0, "[Profile] No profiles defined")
            return
        end
        DisplayTextToPlayer(p, 0, 0, "[Profile] Available:")
        for k, _ in pairs(GameBalance.RespawnProfiles) do
            DisplayTextToPlayer(p, 0, 0, "  " .. tostring(k))
        end
    end)

    registerChat("-profile set", function(p, pid, msg)
        if not _G.RespawnProfile or not RespawnProfile.Set then
            DisplayTextToPlayer(p, 0, 0, "[Profile] Switcher missing")
            return
        end
        local name = parseName(msg, "-profile set")
        if not name or name == "" then
            DisplayTextToPlayer(p, 0, 0, "Usage: -profile set NAME")
            return
        end
        local ok = RespawnProfile.Set(name)
        if ok then
            DisplayTextToPlayer(p, 0, 0, "[Profile] Switched to " .. name)
        else
            DisplayTextToPlayer(p, 0, 0, "[Profile] Unknown profile " .. name)
        end
    end)

    registerChat("-profile current", function(p, pid)
        local id = "?"
        if _G.RespawnProfile and RespawnProfile.CurrentId then
            id = RespawnProfile.CurrentId()
        end
        DisplayTextToPlayer(p, 0, 0, "[Profile] Current: " .. tostring(id))
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
