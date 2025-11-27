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

    -- Simple string arg parser (for ids, names, etc.)
    local function parseArg(msg, cmd)
        -- strip "-cmd " prefix
        local s = string.sub(msg, string.len(cmd) + 1)
        -- remove leading spaces
        local i = 1
        while i <= string.len(s) and string.sub(s, i, i) == " " do
            i = i + 1
        end
        return string.sub(s, i)
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
    -- Displays current Soul XP and level
    registerChat("-souls", function(p, pid)
        if _G.SoulEnergy then
            local getXp = (SoulEnergy.GetXp or SoulEnergy.Get)
            local xp  = getXp and getXp(pid) or 0
            local nxt = SoulEnergy.GetNextXP and SoulEnergy.GetNextXP(pid) or 0
            local lvl = (SoulEnergy.GetLevel and SoulEnergy.GetLevel(pid)) or 1
            DisplayTextToPlayer(p, 0, 0,
                "Soul XP: " .. tostring(xp) .. " / " .. tostring(nxt) .. "  —  Soul Level: " .. tostring(lvl))
        end
    end)

    -- Adds to Soul XP and displays the new value
    registerChat("-souladd", function(p, pid, msg)
        if _G.SoulEnergy then
            local n = parseNum(msg, "-souladd")
            local addFn = SoulEnergy.AddXp or SoulEnergy.Add
            local v = addFn and addFn(pid, n) or 0
            local nxt = SoulEnergy.GetNextXP(pid) or 0
            local lvl = SoulEnergy.GetLevel(pid) or 1
            DisplayTextToPlayer(p, 0, 0, "Soul XP: " .. tostring(v) .. " / " .. tostring(nxt) .. "  —  Soul Level: " .. tostring(lvl))
        end
    end)

    -- Sets the Soul XP and displays the new value
    registerChat("-soulset", function(p, pid, msg)
        if _G.SoulEnergy then
            local n = parseNum(msg, "-soulset")
            local setFn = SoulEnergy.SetXp or SoulEnergy.Set
            local v = setFn and setFn(pid, n) or 0
            local nxt = SoulEnergy.GetNextXP(pid) or 0
            local lvl = SoulEnergy.GetLevel(pid) or 1
            DisplayTextToPlayer(p, 0, 0, "Soul XP: " .. tostring(v) .. " / " .. tostring(nxt) .. "  —  Soul Level: " .. tostring(lvl))
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
    -- World Event Debug Commands
    --------------------------------------------------
    -- Show current world event status
    registerChat("-we_status", function(p, pid)
        local WES = rawget(_G, "WorldEventSystem")
        if not WES or not WES.GetActiveId then
            DisplayTextToPlayer(p, 0, 0, "[WorldEvent] System not available")
            return
        end

        local id = WES.GetActiveId()
        if not id then
            DisplayTextToPlayer(p, 0, 0, "[WorldEvent] No active event")
            return
        end

        local ctx = WES.GetActiveContext and WES.GetActiveContext() or nil
        local def = WES.GetEventDef and WES.GetEventDef(id) or nil

        local name = def and def.name or id
        local zone = def and def.zone or "?"
        local elapsed = ctx and ctx.elapsed or 0
        local duration = def and def.duration or 0

        DisplayTextToPlayer(
            p, 0, 0,
            "[WorldEvent] Active: " ..
                tostring(name) ..
                " (id=" .. tostring(id) ..
                ", zone=" .. tostring(zone) ..
                ", elapsed=" .. tostring(elapsed) ..
                " / " .. tostring(duration) .. "s)"
        )
    end)

    -- Mark an event as ready so it can be rolled
    -- Usage: -we_ready HFIL_SPIRIT_SURGE
    registerChat("-we_ready", function(p, pid, msg)
        local WES = rawget(_G, "WorldEventSystem")
        if not WES or not WES.MarkEventReady then
            DisplayTextToPlayer(p, 0, 0, "[WorldEvent] System not available")
            return
        end

        local id = parseArg(msg, "-we_ready")
        if not id or id == "" then
            DisplayTextToPlayer(p, 0, 0, "[WorldEvent] Usage: -we_ready EVENT_ID")
            return
        end

        WES.MarkEventReady(id)
        DisplayTextToPlayer(p, 0, 0, "[WorldEvent] Marked ready: " .. tostring(id))
    end)

    -- Force end the active event
    registerChat("-we_end", function(p, pid)
        local WES = rawget(_G, "WorldEventSystem")
        if not WES or not WES.ForceEndActive then
            DisplayTextToPlayer(p, 0, 0, "[WorldEvent] System not available")
            return
        end

        if not (WES.GetActiveId and WES.GetActiveId()) then
            DisplayTextToPlayer(p, 0, 0, "[WorldEvent] No active event to end")
            return
        end

        WES.ForceEndActive("debug_end")
        DisplayTextToPlayer(p, 0, 0, "[WorldEvent] Active event force-ended")
    end)

    -- Force a specific event to be the next one (debug helper)
    -- Usage: -we_force HFIL_SPIRIT_SURGE
    registerChat("-we_force", function(p, pid, msg)
        local WES = rawget(_G, "WorldEventSystem")
        if not WES or not WES.GetEventDef or not WES.MarkEventReady then
            DisplayTextToPlayer(p, 0, 0, "[WorldEvent] System not available")
            return
        end

        local id = parseArg(msg, "-we_force")
        if not id or id == "" then
            DisplayTextToPlayer(p, 0, 0, "[WorldEvent] Usage: -we_force EVENT_ID")
            return
        end

        local def = WES.GetEventDef(id)
        if not def then
            DisplayTextToPlayer(p, 0, 0, "[WorldEvent] Unknown event id: " .. tostring(id))
            return
        end

        -- End any current event if possible
        if WES.ForceEndActive then
            WES.ForceEndActive("debug_force")
        end

        -- Mark the chosen event ready so the director will pick it on the next roll
        WES.MarkEventReady(id)
        DisplayTextToPlayer(
            p,
            0,
            0,
            "[WorldEvent] Forced event " ..
                tostring(id) ..
                " (will start as soon as the director rolls again)"
        )
    end)

    --------------------------------------------------
    -- SIMPLE STATS VIEW (fixed)
    --------------------------------------------------
    registerChat("-stats", function(p, pid)
        -- PlayerData part
        local pd   = _G.PlayerData and PlayerData.Get and PlayerData.Get(pid) or nil
        local hero = pd and pd.hero or ( _G.PlayerHero and PlayerHero[pid] ) or nil
        local s    = pd and pd.stats or nil

        local baseStr = s and s.basestr or 0
        local baseAgi = s and s.baseagi or 0
        local baseInt = s and s.baseint or 0

        -- Hero actual stats (only if hero exists)
        local heroStr, heroAgi, heroInt = 0, 0, 0
        if hero and GetUnitTypeId(hero) ~= 0 then
            heroStr = GetHeroStr(hero, false)
            heroAgi = GetHeroAgi(hero, false)
            heroInt = GetHeroInt(hero, false)
        end

        DisplayTextToPlayer(p, 0, 0, "Stats for Player " .. tostring(pid) .. ":")
        DisplayTextToPlayer(p, 0, 0, "Base STR: " .. tostring(baseStr) .. "   (hero: " .. tostring(heroStr) .. ")")
        DisplayTextToPlayer(p, 0, 0, "Base AGI: " .. tostring(baseAgi) .. "   (hero: " .. tostring(heroAgi) .. ")")
        DisplayTextToPlayer(p, 0, 0, "Base INT: " .. tostring(baseInt) .. "   (hero: " .. tostring(heroInt) .. ")")
    end)


    registerChat("-replenish", function(p, pid)
        local hero = PlayerData.GetHero(pid)  -- Get the hero unit
        if hero and GetUnitTypeId(hero) ~= 0 then
            SetWidgetLife(hero,(BlzGetUnitMaxHP(hero)))

        else
            DisplayTextToPlayer(p, 0, 0, "No hero found for this player.")
        end
    end)





end

if Debug and Debug.endFile then Debug.endFile() end
