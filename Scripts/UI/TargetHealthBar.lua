if Debug and Debug.beginFile then Debug.beginFile("TargetingSystem.lua") end
--==================================================
-- TargetingSystem.lua
-- Version: v1.02 (2025-10-25)
--  TAB cycles nearest hostile targets (stable next-in-list)
--  Lock lives on PLAYER_DATA[pid].control.target
--  Marker shown on locked target
--  Auto clears on death or leaving range
--  Emits ProcBus "OnTargetChanged" (target or nil)
--==================================================

do
    --------------------------------------------------
    -- Tunables
    --------------------------------------------------
    local CYCLE_RADIUS            = 1200.0   -- search radius (was 900)
    local FRONT_CONE_DEG          = 140.0    -- prefer units in front
    local CLEAR_RADIUS            = 1200.0   -- clear lock if beyond this
    local RETAIN_ON_OUT_OF_CONE   = true

    -- Marker model. Swap later if you prefer a different ring.
    local FX_MODEL_FALLBACK       = "Abilities\\Spells\\Items\\AIlb\\AIlbTarget.mdl"
    local FX_ATTACH_POINT         = "origin"
    local FX_SCALE                = 1.10

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local MARKER = {}                  -- pid -> effect/fx id
    local ENUM_GROUP = CreateGroup()

    -- stable cycling cache per player
    local CACHE = {}                   -- pid -> { list = {units...}, lastIndex = 0, stamp = 0 }

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0 and not IsUnitType(u, UNIT_TYPE_DEAD)
    end

    local function ensureControl(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]
        if not pd then return nil, nil end
        pd.control = pd.control or { direct=false, target=nil }
        return pd.control, pd
    end

    local function heroOf(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]
        if pd and validUnit(pd.hero) then return pd.hero end
        if _G.PlayerHero and validUnit(PlayerHero[pid]) then return PlayerHero[pid] end
        return nil
    end

    local function isHostile(a, b)
        return IsPlayerEnemy(GetOwningPlayer(a), GetOwningPlayer(b))
    end

    local function angleDiffDeg(a, b)
        local d = a - b
        while d > 180.0 do d = d - 360.0 end
        while d < -180.0 do d = d + 360.0 end
        if d < 0.0 then d = -d end
        return d
    end

    --------------------------------------------------
    -- Marker helpers
    --------------------------------------------------
    local function clearMarker(pid)
        if MARKER[pid] then
            if _G.FXSystem and FXSystem.Destroy then
                pcall(FXSystem.Destroy, MARKER[pid])
            else
                DestroyEffect(MARKER[pid])
            end
            MARKER[pid] = nil
        end
    end

    local function placeMarker(pid, u)
        clearMarker(pid)
        if not validUnit(u) then return end
        if _G.FXSystem and FXSystem.AttachUnit then
            local id = FXSystem.AttachUnit(u, FX_ATTACH_POINT, { model = FX_MODEL_FALLBACK, scale = FX_SCALE, z = 0.0 })
            MARKER[pid] = id
        else
            local e = AddSpecialEffectTarget(FX_MODEL_FALLBACK, u, FX_ATTACH_POINT)
            BlzSetSpecialEffectScale(e, FX_SCALE)
            MARKER[pid] = e
        end
    end

    --------------------------------------------------
    -- Candidate building
    --------------------------------------------------
    local function buildCandidates(pid, uHero)
        GroupClear(ENUM_GROUP)
        local hx, hy = GetUnitX(uHero), GetUnitY(uHero)
        GroupEnumUnitsInRange(ENUM_GROUP, hx, hy, CYCLE_RADIUS, nil)

        local facing = GetUnitFacing(uHero)
        local inCone, all = {}, {}

        local u = FirstOfGroup(ENUM_GROUP)
        while u ~= nil do
            GroupRemoveUnit(ENUM_GROUP, u)
            if validUnit(u) and isHostile(u, uHero) then
                local ux, uy = GetUnitX(u), GetUnitY(u)
                local dx, dy = ux - hx, uy - hy
                local dist2 = dx*dx + dy*dy
                local ang  = math.deg(math.atan(dy, dx))
                local off  = angleDiffDeg(ang, facing)
                local item = { unit = u, dist2 = dist2, off = off, hid = GetHandleId(u) }
                all[#all + 1] = item
                if off <= (FRONT_CONE_DEG * 0.5) then
                    inCone[#inCone + 1] = item
                end
            end
            u = FirstOfGroup(ENUM_GROUP)
        end

        local function byDistStable(a, b)
            if a.dist2 ~= b.dist2 then return a.dist2 < b.dist2 end
            return a.hid < b.hid
        end
        table.sort(inCone, byDistStable)
        table.sort(all, byDistStable)

        -- Return the preferred list (in-cone if any, else all) and also the “all” list
        return (#inCone > 0) and inCone or all, all
    end

    local function setTarget(pid, tgt)
        local c = ensureControl(pid)
        if not c then return end
        c.target = tgt
        if _G.ProcBus and ProcBus.Emit then
            ProcBus.Emit("OnTargetChanged", { pid = pid, target = tgt })
        end
        if tgt then placeMarker(pid, tgt) else clearMarker(pid) end
    end

    --------------------------------------------------
    -- Cycling
    --------------------------------------------------
    local function rebuildCache(pid, list)
        CACHE[pid] = CACHE[pid] or { list = {}, lastIndex = 0, stamp = 0 }
        local arr = {}
        for i = 1, #list do arr[i] = list[i].unit end
        CACHE[pid].list = arr
        CACHE[pid].lastIndex = 0
        CACHE[pid].stamp = CACHE[pid].stamp + 1
    end

    local function indexOf(list, u)
        if not u then return 0 end
        for i = 1, #list do
            if list[i] == u then return i end
        end
        return 0
    end

    local function pickNext(pid)
        local h = heroOf(pid); if not validUnit(h) then return end
        local pref, _ = buildCandidates(pid, h)

        -- refresh cache from current candidates
        rebuildCache(pid, pref)
        local arr = CACHE[pid].list
        if #arr == 0 then
            setTarget(pid, nil)
            return
        end

        local c = ensureControl(pid)
        local cur = c and c.target or nil

        local idx = indexOf(arr, cur)
        local nextIdx
        if idx <= 0 then
            -- start at first; if it equals current somehow, move to second
            nextIdx = 1
            if arr[nextIdx] == cur and #arr > 1 then nextIdx = 2 end
        else
            nextIdx = idx + 1
            if nextIdx > #arr then nextIdx = 1 end
        end

        setTarget(pid, arr[nextIdx])
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    TargetingSystem = TargetingSystem or {}
    function TargetingSystem.Cycle(pid) pickNext(pid) end
    function TargetingSystem.Get(pid)
        local c = ensureControl(pid); if not c then return nil end
        return c.target
    end
    function TargetingSystem.Clear(pid) setTarget(pid, nil) end

    --------------------------------------------------
    -- Maintenance: clear when dead or too far or out of cone
    --------------------------------------------------
    local function maintenance()
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            local c = ensureControl(pid)
            if c and c.target then
                local tgt = c.target
                if not validUnit(tgt) then
                    setTarget(pid, nil)
                else
                    local h = heroOf(pid)
                    if validUnit(h) then
                        local dx = GetUnitX(tgt) - GetUnitX(h)
                        local dy = GetUnitY(tgt) - GetUnitY(h)
                        local d2 = dx*dx + dy*dy
                        if d2 > (CLEAR_RADIUS * CLEAR_RADIUS) then
                            setTarget(pid, nil)
                        elseif not RETAIN_ON_OUT_OF_CONE then
                            local ang = math.deg(math.atan(dy, dx))
                            local off = angleDiffDeg(ang, GetUnitFacing(h))
                            if off > (FRONT_CONE_DEG * 0.5) then
                                setTarget(pid, nil)
                            end
                        end
                    else
                        setTarget(pid, nil)
                    end
                end
            end
        end
    end

    --------------------------------------------------
    -- Wiring
    --------------------------------------------------
    OnInit.final(function()
        if _G.ProcBus and ProcBus.On then
            ProcBus.On("RequestTargetCycle", function(payload)
                if not payload then return end
                local pid = payload.pid
                if type(pid) == "number" then pickNext(pid) end
            end)
        end

        local timer = CreateTimer()
        TimerStart(timer, 0.20, true, maintenance)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("TargetingSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
