if Debug and Debug.beginFile then Debug.beginFile("HFIL_UnitConfig_Dev.lua") end
--==================================================
-- HFIL_UnitConfig_Dev.lua
-- Dev commands for inspecting HFIL_UnitConfig.
-- • -hfillist
-- • -hfilshow <rawcode or numeric FourCC>
--==================================================

do
    local function devOn(pid)
        local DM = rawget(_G, "DevMode")
        local D  = rawget(_G, "Dev")
        if DM and type(DM.IsEnabled) == "function" and DM.IsEnabled() then return true end
        if DM and type(DM.IsOn)      == "function" and DM.IsOn(pid)     then return true end
        if D  and type(D.IsOn)       == "function" and D.IsOn(pid)      then return true end
        return true
    end

    local function reg(prefix, fn)
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(t, Player(i), prefix, false)
        end
        TriggerAddAction(t, function()
            local p   = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            if not devOn(pid) then return end
            local ok, err = pcall(function() fn(p, pid, GetEventPlayerChatString()) end)
            if not ok then DisplayTextToPlayer(p, 0, 0, "[HFIL] cmd error: " .. tostring(err)) end
        end)
    end

    local function trim(s)
        if type(s) ~= "string" then return "" end
        local i, j = 1, #s
        while i <= j do
            local ch = string.sub(s, i, i)
            if ch == " " or ch == "\t" or ch == "\r" or ch == "\n" then i = i + 1 else break end
        end
        while j >= i do
            local ch = string.sub(s, j, j)
            if ch == " " or ch == "\t" or ch == "\r" or ch == "\n" then j = j - 1 else break end
        end
        if j < i then return "" end
        return string.sub(s, i, j)
    end

    local function resolveRow(token)
        if not _G.HFILUnitConfig then return nil end
        local HC = HFILUnitConfig
        if type(HC.GetByTypeId) ~= "function" then return nil end

        -- try direct string id (e.g., "n00G")
        if token and #token == 4 then
            local row = HC.GetByTypeId(token)
            if row then return row end
            if type(FourCC) == "function" then
                local ok, num = pcall(FourCC, token)
                if ok and num then
                    row = HC.GetByTypeId(num)
                    if row then return row end
                end
            end
        end

        -- try numeric input
        local num = tonumber(token or "")
        if num then
            local row = HC.GetByTypeId(num)
            if row then return row end
        end

        return nil
    end

    --------------------------------------------------
    -- -hfillist
    --------------------------------------------------
    reg("-hfillist", function(p)
        if not _G.HFILUnitConfig then
            DisplayTextToPlayer(p, 0, 0, "HFIL_UnitConfig not loaded")
            return
        end
        local list = HFILUnitConfig.List()
        local creeps = list
        local tmp = {}
        for i = 1, #creeps do
            local r = creeps[i]
            tmp[#tmp + 1] = (r.id or "?") .. " " .. (r.name or "")
        end
        table.sort(tmp)
        for i = 1, #tmp do
            DisplayTextToPlayer(p, 0, 0, tmp[i])
        end
    end)

    --------------------------------------------------
    -- -hfilshow <rawcode>
    --------------------------------------------------
    reg("-hfilshow ", function(p, pid, msg)
        local token = trim(string.sub(msg, string.len("-hfilshow ") + 1))
        if token == "" then
            DisplayTextToPlayer(p, 0, 0, "Usage: -hfilshow n00G   or   -hfilshow 123456789")
            return
        end

        local row = resolveRow(token)
        if not row then
            DisplayTextToPlayer(p, 0, 0, "No config for " .. token)
            return
        end

        DisplayTextToPlayer(p, 0, 0, "HFIL " .. (row.name or token))
        DisplayTextToPlayer(p, 0, 0, "baseSoul " .. tostring(row.baseSoul) ..
            " scales " .. tostring(row.scales) ..
            " scaleMult " .. tostring(row.scaleMult) ..
            " share " .. tostring(row.share) ..
            " powerGate " .. tostring(row.powerGate))

        local sd = row.statDrop or {}
        DisplayTextToPlayer(p, 0, 0, "statDrop per mille " .. tostring(sd.chancePermil) ..
            " stat " .. tostring(sd.stat) ..
            " range " .. tostring(sd.min) .. "-" .. tostring(sd.max))

        DisplayTextToPlayer(p, 0, 0, "shard per mille " .. tostring(row.shardChancePermil or 0) ..
            " frag per mille " .. tostring(row.fragChancePermil or 0))

        local ab = row.abilities
        if type(ab) == "table" and #ab > 0 then
            DisplayTextToPlayer(p, 0, 0, "abilities " .. tostring(#ab))
            for i = 1, #ab do
                local a = ab[i]
                local line = "  orderId " .. tostring(a.orderId or 0) ..
                             " target " .. tostring(a.target or "self")
                if a.castWhenHpBelow ~= nil then
                    line = line .. " hpBelow " .. tostring(a.castWhenHpBelow)
                end
                if a.castEvery ~= nil then
                    line = line .. " every " .. tostring(a.castEvery)
                end
                if a.cooldown ~= nil then
                    line = line .. " cd " .. tostring(a.cooldown)
                end
                DisplayTextToPlayer(p, 0, 0, line)
            end
        else
            DisplayTextToPlayer(p, 0, 0, "abilities none")
        end
    end)

    OnInit.final(function()
        local IB = rawget(_G, "InitBroker")
        if IB and type(IB.SystemReady) == "function" then
            InitBroker.SystemReady("HFIL_UnitConfig_Dev")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
