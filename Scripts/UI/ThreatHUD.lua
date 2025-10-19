if Debug and Debug.beginFile then Debug.beginFile("CombatThreatHUD.lua") end
--==================================================
-- CombatThreatHUD.lua
-- Tiny top-right threat and group dps overlay.
-- • Shows top entries for the player's current focus target
-- • Focus target = last unit this player damaged recently
-- • Uses ThreatSystem.GetThreat for values
-- • Tracks recent attackers per target via ProcBus OnDealtDamage
-- • No percent symbols anywhere
--==================================================

if not CombatThreatHUD then CombatThreatHUD = {} end
_G.CombatThreatHUD = CombatThreatHUD

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local W, H         = 0.19, 0.12     -- panel size
    local LINE_H       = 0.014
    local MAX_LINES    = 6              -- header plus 5 entries
    local FOCUS_TTL    = 4.0            -- seconds to keep focus after last hit
    local SEEN_TTL     = 6.0            -- seconds to keep a source associated to a target
    local DPS_WINDOW   = 5.0            -- seconds rolling dps window
    local REFRESH_SEC  = 0.25

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local visible = {}        -- visible[pid] = bool
    local roots   = {}        -- roots[pid] = frame
    local lines   = {}        -- lines[pid] = {frame,...}
    local focus   = {}        -- focus[pid] = { unit=target, last=clock }
    local seen    = {}        -- seen[targetH] = { [srcH] = { unit=src, last=clock } }
    local dmgLog  = {}        -- dmgLog[targetH] = array of { t=clock, n=amount }

    CombatThreatHUD.visible = visible  -- exposed for chat feedback

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function now()
        if os and os.clock then return os.clock() end
        return 0
    end
    local function hid(h) if not h then return nil end return GetHandleId(h) end
    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function ensureUI(pid)
        if roots[pid] then return end
        local ui = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)

        local root = BlzCreateFrameByType("BACKDROP", "CTHUD_"..pid, ui, "", 0)
        roots[pid] = root
        BlzFrameSetSize(root, W, H)
        -- top right
        BlzFrameSetPoint(root, FRAMEPOINT_TOPRIGHT, ui, FRAMEPOINT_TOPRIGHT, -0.016, -0.016)
        BlzFrameSetTexture(root, "UI\\Widgets\\EscMenu\\Human\\blank-background.blp", 0, true)
        BlzFrameSetVisible(root, false)

        lines[pid] = {}
        for i=1, MAX_LINES do
            local t = BlzCreateFrameByType("TEXT", "CTHUD_Line_"..pid.."_"..i, root, "", 0)
            lines[pid][i] = t
            BlzFrameSetScale(t, 1.00)
            BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
            local y = -0.006 - (i - 1) * LINE_H
            BlzFrameSetPoint(t, FRAMEPOINT_TOPLEFT, root, FRAMEPOINT_TOPLEFT, 0.006, y)
            BlzFrameSetText(t, "")
        end
    end

    local function setVisible(pid, flag)
        ensureUI(pid)
        visible[pid] = flag and true or false
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(roots[pid], visible[pid])
        end
    end

    local function trimName(u)
        local n = GetUnitName(u) or "Unit"
        if string.len(n) > 20 then
            n = string.sub(n, 1, 20)
        end
        return n
    end

    local function addDmgSample(tgtH, amount)
        if amount <= 0 then return end
        dmgLog[tgtH] = dmgLog[tgtH] or {}
        local arr = dmgLog[tgtH]
        arr[#arr+1] = { t = now(), n = amount }
        -- prune
        local cut = now() - DPS_WINDOW
        local k = 1
        while k <= #arr do
            if arr[k].t < cut then table.remove(arr, k) else k = k + 1 end
        end
    end

    local function getGroupDPS(tgtH)
        local arr = dmgLog[tgtH]
        if not arr or #arr == 0 then return 0 end
        local sum = 0
        for i=1,#arr do sum = sum + (arr[i].n or 0) end
        local span = DPS_WINDOW
        return math.floor(sum / math.max(0.25, span) + 0.5)
    end

    local function setText(pid, idx, txt)
        local t = lines[pid] and lines[pid][idx]
        if not t then return end
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetText(t, txt or "")
        end
    end

    --------------------------------------------------
    -- Public
    --------------------------------------------------
    function CombatThreatHUD.Toggle(pid)
        if not roots[pid] then ensureUI(pid) end
        setVisible(pid, not visible[pid])
    end

    --------------------------------------------------
    -- Event wiring
    --------------------------------------------------
    local function onHit(e)
        if not e then return end
        local pid   = e.pid
        local src   = e.source
        local tgt   = e.target
        local amt   = tonumber(e.amount or 0) or 0
        if pid == nil or not validUnit(src) or not validUnit(tgt) then return end

        -- remember focus for this player
        focus[pid] = { unit = tgt, last = now() }

        -- remember that src participated on tgt
        local th = hid(tgt); local sh = hid(src)
        if th and sh then
            seen[th] = seen[th] or {}
            seen[th][sh] = { unit = src, last = now() }
        end

        -- log damage for dps window
        if th then addDmgSample(th, amt) end
    end

    local function onKill(e)
        if not e then return end
        local tgt = e.target
        if not validUnit(tgt) then return end
        local th = hid(tgt)
        if th then
            seen[th]   = nil
            dmgLog[th] = nil
        end
        -- clear focus for any player staring at this target
        for pid=0,bj_MAX_PLAYERS-1 do
            if focus[pid] and focus[pid].unit == tgt then
                focus[pid] = nil
            end
        end
    end

    --------------------------------------------------
    -- Updater
    --------------------------------------------------
    local function refresh()
        local tnow = now()

        -- prune stale entries in seen
        for th, map in pairs(seen) do
            for sh, rec in pairs(map) do
                if not rec or not validUnit(rec.unit) or (tnow - (rec.last or 0)) > SEEN_TTL then
                    map[sh] = nil
                end
            end
            if next(map) == nil then
                seen[th] = nil
            end
        end

        -- update each visible player's panel
        for pid=0,bj_MAX_PLAYERS-1 do
            if visible[pid] then
                local header = "Threat"
                local target = focus[pid] and focus[pid].unit
                if target and validUnit(target) and (tnow - (focus[pid].last or 0)) <= FOCUS_TTL then
                    local th = hid(target)
                    local nameT = trimName(target)
                    local dps = getGroupDPS(th)
                    setText(pid, 1, nameT .. "  DPS " .. tostring(dps))

                    -- gather entries from seen
                    local list = {}
                    local map = seen[th] or {}
                    for sh, rec in pairs(map) do
                        local u = rec.unit
                        if validUnit(u) and _G.ThreatSystem and ThreatSystem.GetThreat then
                            local v = ThreatSystem.GetThreat(u, target) or 0
                            if v > 0 then
                                list[#list+1] = { unit=u, val=v }
                            end
                        end
                    end
                    -- sort by value
                    table.sort(list, function(a,b) return (a.val or 0) > (b.val or 0) end)

                    -- render up to 5
                    local line = 2
                    for i=1, math.min(5, #list) do
                        local u = list[i].unit
                        local v = list[i].val
                        setText(pid, line, tostring(i) .. ". " .. trimName(u) .. "  " .. tostring(v))
                        line = line + 1
                    end
                    -- clear remaining lines
                    while line <= MAX_LINES do
                        setText(pid, line, "")
                        line = line + 1
                    end
                else
                    -- no focus
                    setText(pid, 1, "No target")
                    for i=2,MAX_LINES do setText(pid, i, "") end
                end
            end
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        -- wire ProcBus if present
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnDealtDamage", onHit)
            PB.On("OnKill", onKill)
        end

        -- start updater
        local tick = CreateTimer()
        TimerStart(tick, REFRESH_SEC, true, function()
            local ok, err = pcall(refresh)
            if not ok and Debug and Debug.printf then
                Debug.printf("[CTHUD] refresh error "..tostring(err))
            end
        end)

        -- do not show by default
        for pid=0,bj_MAX_PLAYERS-1 do setVisible(pid, false) end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CombatThreatHUD")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
