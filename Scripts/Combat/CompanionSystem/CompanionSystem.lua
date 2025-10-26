if Debug and Debug.beginFile then Debug.beginFile("CompanionSystem.lua") end
--==================================================
-- CompanionSystem.lua (v1.0 MAIN)
-- Summon, follow, and basic assist AI for companions.
-- Safe strings for Warcraft Three. No percent symbols used.
-- Anti jitter follow with cooldown, hysteresis, and sticky idle anchor.
--==================================================

if not CompanionSystem then CompanionSystem = {} end
_G.CompanionSystem = CompanionSystem

do
  --------------------------------------------------
  -- Config
  --------------------------------------------------
  local THINK_PERIOD        = 0.60   -- seconds between AI ticks
  local HEAL_CHECK_PERIOD   = 0.30
  local ASSIST_CHECK_PERIOD = 0.30

  -- Follow thresholds and spacing
  -- Hysteresis band: no orders if within DIST_MIN .. BAND_TIGHT
  local INNER_BACKOFF       = 240.0  -- back off if closer than this
  local DIST_MIN            = 260.0  -- desired inner ring
  local BAND_TIGHT          = 380.0  -- upper bound of comfy zone
  local OUTER_CATCHUP       = 400.0  -- attack move toward owner if beyond this
  local BAND_LOOSE          = 600.0  -- used when player sets loose band
  local CHASE_LIMIT         = 900.0
  local SNAP_DISTANCE       = 1800.0

  -- Idle anchor behavior
  local IDLE_ANCHOR_RADIUS        = 60.0      -- ring around owner for idle anchor
  local IDLE_ANCHOR_DURATION      = 4.0       -- seconds to keep same idle anchor
  local IDLE_ANCHOR_OWNER_REPICK  = 260.0     -- repick if owner moved this far

  -- Order management
  local ORDER_COOLDOWN      = 1.00   -- minimum seconds between issued orders
  local DEST_EPS            = 100.0  -- skip reissuing near identical move
  local DEBUG_MSGS          = false

  -- Healer behavior
  local HEAL_THRESHOLD_PCT  = 0.70   -- heal owner under this ratio
  local HEAL_ORDER_ID       = 852067 -- generic heal order id, can be overridden per template

  local function now()
    if os and os.clock then return os.clock() end
    return 0
  end

  local function dbg(pid, msg)
    if DEBUG_MSGS then
      DisplayTextToPlayer(Player(pid), 0, 0, "[Companion] " .. tostring(msg))
    end
  end

  --------------------------------------------------
  -- State
  --------------------------------------------------
  -- R[pid] = {
  --   u, role, template,
  --   thinkT, healT, assistT,
  --   lastOrderAt, lastDestX, lastDestY,
  --   idleAnchorX, idleAnchorY, idleAnchorUntil,
  --   idleOwnerX, idleOwnerY
  -- }
  local R = {}

  local function ensureState(pid)
    local t = R[pid]
    if not t then
      t = {
        u=nil, role="HEALER", template=nil,
        thinkT=nil, healT=nil, assistT=nil,
        lastOrderAt=0, lastDestX=nil, lastDestY=nil,
        idleAnchorX=nil, idleAnchorY=nil, idleAnchorUntil=0,
        idleOwnerX=nil, idleOwnerY=nil
      }
      R[pid] = t
    end
    return t
  end

  --------------------------------------------------
  -- Helpers
  --------------------------------------------------
  local function getOwnerUnit(pid)
    local PD = rawget(_G, "PlayerData")
    if PD and PD.GetHero then return PD.GetHero(pid) end
    return nil
  end

  local function getFollowBand(pid)
    local PD = rawget(_G, "PlayerData"); if not PD then return BAND_TIGHT end
    local m = PD.GetMerc and PD.GetMerc(pid) or nil
    if not m then return BAND_TIGHT end
    return (m.band == "loose") and BAND_LOOSE or BAND_TIGHT
  end

  local function setPDActive(pid, unit, role)
    local PD = rawget(_G, "PlayerData"); if not PD then return end
    local m = PD.GetMerc and PD.GetMerc(pid) or nil; if not m then return end
    m.active = unit ~= nil
    m.unit   = unit
    if role then m.role = role end
  end

  local function routeThreatSetup(pid, role, template)
    local PD = rawget(_G, "PlayerData"); if not PD then return end
    local m  = PD.GetMerc and PD.GetMerc(pid) or nil; if not m then return end
    if role == "TANK" then
      m.threatPolicy.threatMode = "self"
      m.threatPolicy.threatMultSelf = 1.2
      m.threatPolicy.threatMultOwner = 0.0
    else
      m.threatPolicy.threatMode = "owner"
      m.threatPolicy.threatMultSelf = 0.0
      m.threatPolicy.threatMultOwner = 1.0
    end
    if template and template.threatPolicy then
      for k,v in pairs(template.threatPolicy) do m.threatPolicy[k] = v end
    end
    local PB = rawget(_G, "ProcBus")
    if PB and PB.Emit then PB.Emit("CompanionThreatPolicy", { pid=pid, policy=m.threatPolicy }) end
  end

  local function catalogGet(templateId)
    if _G.CompanionCatalog and CompanionCatalog.Get then
      local ok, data = pcall(CompanionCatalog.Get, templateId)
      if ok and type(data) == "table" then return data end
    end
    return nil
  end

  local function pickAround(x, y, radius)
    local a = math.random() * 6.2831853
    return x + radius * math.cos(a), y + radius * math.sin(a)
  end

  local function dist2(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return dx*dx + dy*dy
  end

  local function canIssue(pid, x, y)
    local st = ensureState(pid)
    local t  = now()
    if (t - (st.lastOrderAt or 0)) < ORDER_COOLDOWN then
      return false
    end
    if st.lastDestX and st.lastDestY then
      if dist2(st.lastDestX, st.lastDestY, x, y) <= (DEST_EPS * DEST_EPS) then
        return false
      end
    end
    st.lastOrderAt = t
    st.lastDestX, st.lastDestY = x, y
    return true
  end

  local function clearIdleAnchor(st)
    st.idleAnchorX, st.idleAnchorY, st.idleAnchorUntil = nil, nil, 0
    st.idleOwnerX, st.idleOwnerY = nil, nil
  end

  local function ensureIdleAnchor(pid, ownerX, ownerY)
    local st = ensureState(pid)
    local t = now()
    local needNew = false

    if not st.idleAnchorX or not st.idleAnchorY or t > (st.idleAnchorUntil or 0) then
      needNew = true
    else
      if st.idleOwnerX and st.idleOwnerY then
        if dist2(st.idleOwnerX, st.idleOwnerY, ownerX, ownerY) > (IDLE_ANCHOR_OWNER_REPICK * IDLE_ANCHOR_OWNER_REPICK) then
          needNew = true
        end
      else
        needNew = true
      end
    end

    if needNew then
      local ax, ay = pickAround(ownerX, ownerY, DIST_MIN + IDLE_ANCHOR_RADIUS)
      st.idleAnchorX, st.idleAnchorY = ax, ay
      st.idleOwnerX,  st.idleOwnerY  = ownerX, ownerY
      st.idleAnchorUntil = t + IDLE_ANCHOR_DURATION
    end

    return st.idleAnchorX, st.idleAnchorY
  end

  --------------------------------------------------
  -- Movement and AI
  --------------------------------------------------
  local function thinkFollow(pid, u, owner)
    if not u or not owner then return end

    local ux, uy = GetUnitX(u), GetUnitY(u)
    local ox, oy = GetUnitX(owner), GetUnitY(owner)
    local d2     = dist2(ux, uy, ox, oy)

    -- Hard snap if extremely far
    if d2 > SNAP_DISTANCE * SNAP_DISTANCE then
      local sx, sy = pickAround(ox, oy, DIST_MIN)
      SetUnitPosition(u, sx, sy)
      clearIdleAnchor(ensureState(pid))
      return
    end

    local bandTop = getFollowBand(pid)

    -- Back off if too close
    if d2 < (INNER_BACKOFF * INNER_BACKOFF) then
      local dir = Atan2(uy - oy, ux - ox)
      local tx = ox + DIST_MIN * math.cos(dir)
      local ty = oy + DIST_MIN * math.sin(dir)
      if canIssue(pid, tx, ty) then
        IssuePointOrderById(u, 851986, tx, ty) -- move
        dbg(pid, "Backoff move")
      end
      return
    end

    -- Catch up if outside outer bound
    local outer = math.max(bandTop, OUTER_CATCHUP)
    if d2 > (outer * outer) then
      if canIssue(pid, ox, oy) then
        IssuePointOrderById(u, 851983, ox, oy) -- attack move to owner
        dbg(pid, "Catchup attack move")
      end
      return
    end

    -- Inside hysteresis band. Idle logic with sticky anchor.
    -- If already has a current order, let it complete.
    if GetUnitCurrentOrder(u) ~= 0 then
      return
    end

    local ax, ay = ensureIdleAnchor(pid, ox, oy)
    if canIssue(pid, ax, ay) then
      IssuePointOrderById(u, 851986, ax, ay) -- calm move toward idle anchor
      dbg(pid, "Idle anchor move")
    end
  end

  local function thinkHeal(pid, u, owner, template)
    if not u or not owner then return end
    local mhp = BlzGetUnitMaxHP(owner)
    if mhp <= 1 then return end
    local ratio = GetWidgetLife(owner) / mhp
    if ratio <= HEAL_THRESHOLD_PCT then
      local orderId = HEAL_ORDER_ID
      if template and template.healAbilityId then orderId = template.healAbilityId end
      IssueTargetOrderById(u, orderId, owner)
    end
  end

  local function thinkAssist(pid, u, owner)
    if not u or not owner then return end
    -- Use your targeting control first
    local PD = rawget(_G, "PlayerData")
    local control = PD and PD.GetControl and PD.GetControl(pid) or nil
    local tgt = control and control.target or nil

    -- If no explicit target, try threat systems for any current target that this player owns threat on
    if (not tgt) or (not IsUnitAliveBJ(tgt)) then
      local AM = rawget(_G, "AggroManager")
      if AM and AM.GetAnyTargetForPid then
        tgt = AM.GetAnyTargetForPid(pid)
      end
    end

    if tgt and IsUnitAliveBJ(tgt) then
      IssueTargetOrderById(u, 851983, tgt) -- attack target
    end
  end

  local function ensureTimers(pid)
    local st = ensureState(pid)

    if not st.thinkT then
      st.thinkT = CreateTimer()
      TimerStart(st.thinkT, THINK_PERIOD, true, function()
        local u = st.u; if not u then return end
        local owner = getOwnerUnit(pid)
        if not owner or not IsUnitAliveBJ(owner) then return end

        -- Follow brain always runs
        thinkFollow(pid, u, owner)

        -- If in combat, assist brain can be nudged here as well for responsiveness
        local inCombat = _G.CombatEventsBridge and CombatEventsBridge.IsInCombat and CombatEventsBridge.IsInCombat(pid)
        if inCombat then
          -- Only issue if unit currently has no active order to avoid spam
          if GetUnitCurrentOrder(u) == 0 then
            thinkAssist(pid, u, owner)
          end
        end
      end)
    end

    if not st.healT then
      st.healT = CreateTimer()
      TimerStart(st.healT, HEAL_CHECK_PERIOD, true, function()
        local u = st.u; if not u then return end
        if st.role ~= "HEALER" then return end
        local owner = getOwnerUnit(pid)
        if not owner or not IsUnitAliveBJ(owner) then return end
        thinkHeal(pid, u, owner, st.template or nil)
      end)
    end

    if not st.assistT then
      st.assistT = CreateTimer()
      TimerStart(st.assistT, ASSIST_CHECK_PERIOD, true, function()
        local u = st.u; if not u then return end
        local owner = getOwnerUnit(pid)
        if not owner or not IsUnitAliveBJ(owner) then return end

        local inCombat = _G.CombatEventsBridge and CombatEventsBridge.IsInCombat and CombatEventsBridge.IsInCombat(pid)
        if inCombat then
          thinkAssist(pid, u, owner)
        end
      end)
    end
  end

  local function stopTimers(pid)
    local st = ensureState(pid)
    local t = st.thinkT; if t then PauseTimer(t); DestroyTimer(t); st.thinkT=nil end
    local h = st.healT;  if h then PauseTimer(h); DestroyTimer(h); st.healT=nil end
    local a = st.assistT;if a then PauseTimer(a); DestroyTimer(a); st.assistT=nil end
  end

  --------------------------------------------------
  -- Spawn and Despawn
  --------------------------------------------------
  local function spawnUnitFor(pid, template)
    local owner = getOwnerUnit(pid); if not owner then dbg(pid, "No owner hero"); return nil end
    if not template or not template.unitTypeId then dbg(pid, "Bad template for summon"); return nil end

    local ox, oy = GetUnitX(owner), GetUnitY(owner)
    local sx, sy = pickAround(ox, oy, DIST_MIN)
    local p      = Player(pid)
    local u      = CreateUnit(p, template.unitTypeId, sx, sy, 0.0)
    if not u then dbg(pid, "CreateUnit failed"); return nil end

    if template.name then BlzSetUnitName(u, template.name) end

    local st = ensureState(pid)
    st.u = u
    st.role = (template.role and string.upper(template.role)) or "HEALER"
    st.template = template
    st.lastOrderAt = 0
    st.lastDestX, st.lastDestY = nil, nil
    clearIdleAnchor(st)

    setPDActive(pid, u, st.role)
    routeThreatSetup(pid, st.role, template)

    local PB = rawget(_G, "ProcBus")
    if PB and PB.Emit then PB.Emit("CompanionSpawned", { pid=pid, unit=u, template=template }) end

    return u
  end

  local function despawn(pid)
    stopTimers(pid)
    local st = ensureState(pid)
    if st.u and GetUnitTypeId(st.u) ~= 0 then
      RemoveUnit(st.u)
    end
    st.u, st.template = nil, nil
    st.lastDestX, st.lastDestY = nil, nil
    clearIdleAnchor(st)
    setPDActive(pid, nil, nil)
    local PB = rawget(_G, "ProcBus")
    if PB and PB.Emit then PB.Emit("CompanionDespawned", { pid=pid }) end
  end

  --------------------------------------------------
  -- Public API
  --------------------------------------------------
  function CompanionSystem.Summon(pid, templateId)
    local PD = rawget(_G, "PlayerData")
    if not PD then dbg(pid, "PlayerData missing"); return false end
    if not PD.HasCompanionUnlocked or not PD.HasCompanionUnlocked(pid, templateId) then
      dbg(pid, "Not unlocked: " .. tostring(templateId))
      return false
    end

    local t = catalogGet(templateId)
    if not t then dbg(pid, "Template not found: " .. tostring(templateId)); return false end

    local st = ensureState(pid)
    if st.u then despawn(pid) end

    local u = spawnUnitFor(pid, t)
    if not u then return false end

    ensureTimers(pid)
    dbg(pid, "Summoned " .. (t.name or t.id or "Companion"))
    return true
  end

  function CompanionSystem.Despawn(pid)
    despawn(pid)
    dbg(pid, "Despawned companion")
    return true
  end

  function CompanionSystem.Toggle(pid, templateId)
    local st = ensureState(pid)
    if st.u then return CompanionSystem.Despawn(pid) else return CompanionSystem.Summon(pid, templateId) end
  end

  function CompanionSystem.RefreshFromPlayerData(pid)
    local st = ensureState(pid)
    if st.u then
      routeThreatSetup(pid, st.role, st.template)
    end
  end

  --------------------------------------------------
  -- Init
  --------------------------------------------------
  OnInit.final(function()
    if rawget(_G, "InitBroker") and InitBroker.SystemReady then
      InitBroker.SystemReady("CompanionSystem")
    end
  end)
end

if Debug and Debug.endFile then Debug.endFile() end
