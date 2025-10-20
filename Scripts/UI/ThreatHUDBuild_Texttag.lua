if Debug and Debug.beginFile then Debug.beginFile("ThreatHUDBuild_Texttag.lua") end
--==================================================
-- ThreatHUDBuild: texttag HUD (target + top entries)
-- Update(pid, list, targetName)
--==================================================

if not ThreatHUDBuild then ThreatHUDBuild = {} end
_G.ThreatHUDBuild = ThreatHUDBuild

do
    local tagByPid = {}
    local shown    = {}

    local function valid(u) return u and GetUnitTypeId(u) ~= 0 end
    local function heroOf(pid)
        if _G.PlayerData and PlayerData.GetHero then return PlayerData.GetHero(pid) end
        return nil
    end
    local function withLocal(pid, fn)
        if GetLocalPlayer() == Player(pid) then fn() end
    end

    function ThreatHUDBuild.Create(pid)
        if tagByPid[pid] then return tagByPid[pid] end
        local tt = CreateTextTag()
        tagByPid[pid] = tt
        shown[pid] = false
        withLocal(pid, function()
            SetTextTagPermanent(tt, true)
            SetTextTagVisibility(tt, false)
            SetTextTagText(tt, "Threat", 0.023)
            SetTextTagColor(tt, 255, 220, 0, 255)
        end)
        return tt
    end

    function ThreatHUDBuild.SetVisible(pid, on)
        local tt = tagByPid[pid]; if not tt then return end
        shown[pid] = on and true or false
        withLocal(pid, function() SetTextTagVisibility(tt, shown[pid]) end)
    end

    function ThreatHUDBuild.Update(pid, list, targetName)
        local tt = tagByPid[pid]; if not tt then return end
        local h = heroOf(pid)
        local lines = {}
        lines[#lines + 1] = (targetName and targetName ~= "" and targetName) or "Threat"
        local max = math.min(5, list and #list or 0)
        for i = 1, max do
            local e = list[i]
            local dps = e and e.dps or 0
            local th  = e and e.threat or 0
            local nm  = (e and e.name) or "P?"
            lines[#lines + 1] = nm .. "  DPS: " .. string.format("%.2f", dps) .. "  Threat: " .. tostring(math.floor(th))
        end
        local text = table.concat(lines, "\n")
        withLocal(pid, function()
            if valid(h) then SetTextTagPosUnit(tt, h, 60.0) end
            SetTextTagText(tt, text, 0.023)
        end)
    end

    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatHUDBuild_Texttag")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
