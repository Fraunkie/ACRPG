if Debug and Debug.beginFile then Debug.beginFile("CustomSpellBar.lua") end
--==================================================
-- CustomSpellBar.lua  (MAIN)
-- Bottom-centered single row of 10 custom ability buttons
--  • Buttons are ~half default size (tweak with constants below)
--  • Uses WORLD_FRAME parent (so it won’t be clipped by Console UI)
--  • Hover glow + simple tooltip
--  • NEW: Public ActivateSlot(pid, slot) for hotkeys; shows "No ability" if empty
--==================================================

if not CustomSpellBar then CustomSpellBar = {} end
_G.CustomSpellBar = CustomSpellBar

do
    --------------------------------------------------
    -- TUNABLES (easy sizing/centering)
    --------------------------------------------------
    local SLOT_COUNT   = 10

    -- Overall scale for the bar; change this to quickly resize everything
    local SCALE        = 1.00

    -- Base cell size (roughly half a default command button at 1.0 scale)
    local BASE_CELL    = 0.040      -- width/height
    local CELL_W       = BASE_CELL * SCALE
    local CELL_H       = BASE_CELL * SCALE

    -- Spacing and padding
    local BASE_GAP_X   = 0.006
    local BASE_GAP_Y   = 0.006
    local GAP_X        = BASE_GAP_X * SCALE
    local GAP_Y        = BASE_GAP_Y * SCALE
    local PAD          = 0.004 * SCALE

    -- Bottom offset from the screen edge
    local BOTTOM_Y     = 0.012 * SCALE

    -- Horizontal nudge (Positive = move right, Negative = move left)
    -- (kept from your current main file)
    local ALIGN_X      = 0.25

    -- Tooltip sizing
    local TIP_W        = 0.16
    local TIP_H        = 0.05
    local TIP_PAD      = 0.006

    --------------------------------------------------
    -- ABILITY MAP (fill with your real data later)
    --------------------------------------------------
    -- orderType: "instant" | "point" | "target"
    -- orderId: base order id (Issue*OrderById)
    -- icon: BTN path
    -- name: tooltip
    local SPELL_LAYOUT = {
        -- ["A006"] = { slot=1, icon="ReplaceableTextures\\CommandButtons\\BTNKamehameha.blp", orderType="point",   orderId=852183, name="Kamehameha" },
        -- ["A019"] = { slot=2, icon="ReplaceableTextures\\CommandButtons\\BTNKaioken.blp",    orderType="instant", orderId=852586, name="Kaioken"    },
    }

    -- Show placeholders for unlearned slots while testing
    local SHOW_PLACEHOLDERS = true
    local EMPTY_ICON        = "war3mapImported\\SpellEmpty.blp"  -- your imported anime-ish empty icon

    -- Visual assets
    local BTN_BG   = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller"
    local BTN_MASK = "UI\\Feedback\\AutocastButton.blp"   -- hover ring

    -- Computed bar size
    local BAR_W = SLOT_COUNT*CELL_W + (SLOT_COUNT-1)*GAP_X + 2*PAD
    local BAR_H = CELL_H + 2*PAD

    local POLL_DT = 0.25

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local root  = {}  -- pid -> bar root
    local slots = {}  -- pid -> { [1..SLOT_COUNT] = {btn,icon,ring,tip,tipBg,abilRaw} }
    local hero  = {}  -- pid -> unit

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function abilId(raw) return type(raw)=="string" and FourCC(raw) or raw end
    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function hasAbility(u, raw)
        if not validUnit(u) then return false end
        return GetUnitAbilityLevel(u, abilId(raw)) > 0
    end

    local function makeTooltip(parent, w, h)
        local bg = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)
        BlzFrameSetSize(bg, w, h)
        BlzFrameSetTexture(bg, "UI\\Widgets\\EscMenu\\Human\\blank-background.blp", 0, true)
        BlzFrameSetAlpha(bg, 200)
        BlzFrameSetVisible(bg, false)

        local t = BlzCreateFrameByType("TEXT", "", bg, "", 0)
        BlzFrameSetPoint(t, FRAMEPOINT_TOPLEFT,     bg, FRAMEPOINT_TOPLEFT,     TIP_PAD, -TIP_PAD)
        BlzFrameSetPoint(t, FRAMEPOINT_BOTTOMRIGHT, bg, FRAMEPOINT_BOTTOMRIGHT, -TIP_PAD,  TIP_PAD)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(t, "")
        BlzFrameSetVisible(t, false)
        return bg, t
    end

    local function showTooltip(bg, t, anchor, title)
        BlzFrameSetText(t, title or "")
        BlzFrameClearAllPoints(bg)
        BlzFrameSetPoint(bg, FRAMEPOINT_BOTTOM, anchor, FRAMEPOINT_TOP, 0.0, 0.006)
        BlzFrameSetVisible(bg, true)
        BlzFrameSetVisible(t,  true)
    end
    local function hideTooltip(bg, t)
        BlzFrameSetVisible(t,  false)
        BlzFrameSetVisible(bg, false)
    end

    --------------------------------------------------
    -- Build UI
    --------------------------------------------------
    local function ensureBar(pid)
        if root[pid] then return end

        local parent = BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0)
        local r = BlzCreateFrameByType("FRAME", "SpellBarRoot"..pid, parent, "", 0)
        root[pid] = r
        BlzFrameSetSize(r, BAR_W, BAR_H)
        -- perfectly centered; ALIGN_X lets you nudge if needed
        BlzFrameSetPoint(r, FRAMEPOINT_BOTTOM, parent, FRAMEPOINT_BOTTOM, ALIGN_X, BOTTOM_Y)
        BlzFrameSetLevel(r, 10)

        slots[pid] = {}
        for i=1, SLOT_COUNT do
            local col = i - 1
            local cx = -BAR_W*0.5 + PAD + col*(CELL_W + GAP_X)
            local cy = PAD

            local btn = BlzCreateFrameByType("BUTTON", "SpellBtn"..pid.."_"..i, r, "", 0)
            BlzFrameSetSize(btn, CELL_W, CELL_H)
            BlzFrameSetPoint(btn, FRAMEPOINT_BOTTOMLEFT, r, FRAMEPOINT_BOTTOMLEFT, cx, cy)

            local bg = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
            BlzFrameSetAllPoints(bg, btn)
            BlzFrameSetTexture(bg, BTN_BG, 0, true)

            local icon = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
            BlzFrameSetAllPoints(icon, btn)
            BlzFrameSetTexture(icon, EMPTY_ICON, 0, true)
            BlzFrameSetAlpha(icon, SHOW_PLACEHOLDERS and 120 or 20)

            local ring = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
            BlzFrameSetAllPoints(ring, btn)
            BlzFrameSetTexture(ring, BTN_MASK, 0, true)
            BlzFrameSetAlpha(ring, 0)

            local tipBg, tipText = makeTooltip(btn, TIP_W, TIP_H)

            local tEnter = CreateTrigger()
            BlzTriggerRegisterFrameEvent(tEnter, btn, FRAMEEVENT_MOUSE_ENTER)
            TriggerAddAction(tEnter, function()
                BlzFrameSetAlpha(ring, 200)
                local entry = slots[pid][i]
                local title = "Empty Slot"
                if entry and entry.abilRaw then
                    local spec = SPELL_LAYOUT[entry.abilRaw]
                    if spec and spec.name then title = spec.name end
                end
                showTooltip(tipBg, tipText, btn, title)
            end)

            local tLeave = CreateTrigger()
            BlzTriggerRegisterFrameEvent(tLeave, btn, FRAMEEVENT_MOUSE_LEAVE)
            TriggerAddAction(tLeave, function()
                BlzFrameSetAlpha(ring, 0)
                hideTooltip(tipBg, tipText)
            end)

            local tClick = CreateTrigger()
            BlzTriggerRegisterFrameEvent(tClick, btn, FRAMEEVENT_CONTROL_CLICK)
            TriggerAddAction(tClick, function()
                if GetLocalPlayer() ~= Player(pid) then return end
                CustomSpellBar.ActivateSlot(pid, i)
            end)

            slots[pid][i] = { btn=btn, icon=icon, ring=ring, tip=tipText, tipBg=tipBg, abilRaw=nil }
        end
    end

    --------------------------------------------------
    -- Refresh
    --------------------------------------------------
    local function refresh(pid)
        local u = hero[pid]
        for i=1, SLOT_COUNT do
            local e = slots[pid][i]
            if e then
                BlzFrameSetTexture(e.icon, EMPTY_ICON, 0, true)
                BlzFrameSetAlpha(e.icon, SHOW_PLACEHOLDERS and 120 or 20)
                e.abilRaw = nil
            end
        end
        if not validUnit(u) then return end
        for raw, spec in pairs(SPELL_LAYOUT) do
            local slot = spec.slot
            if slot and slot >= 1 and slot <= SLOT_COUNT then
                local e = slots[pid][slot]
                if e then
                    if hasAbility(u, raw) then
                        BlzFrameSetTexture(e.icon, spec.icon or EMPTY_ICON, 0, true)
                        BlzFrameSetAlpha(e.icon, 255)
                        e.abilRaw = raw
                    else
                        BlzFrameSetTexture(e.icon, spec.icon or EMPTY_ICON, 0, true)
                        BlzFrameSetAlpha(e.icon, 60)
                        e.abilRaw = nil
                    end
                end
            end
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function CustomSpellBar.BindHero(pid, u)
        hero[pid] = u
        if GetLocalPlayer() == Player(pid) then refresh(pid) end
    end

    function CustomSpellBar.Refresh(pid)
        if GetLocalPlayer() == Player(pid) then refresh(pid) end
    end

    -- NEW: allow KeyEventHandler to trigger a slot just like clicking it
    function CustomSpellBar.ActivateSlot(pid, slotIndex)
        if GetLocalPlayer() ~= Player(pid) then return end
        local e = slots[pid] and slots[pid][slotIndex]
        if not e then return end
        local u = hero[pid]
        if not validUnit(u) then
            DisplayTextToPlayer(Player(pid), 0, 0, "No ability in this slot.")
            return
        end
        local raw = e.abilRaw
        if not raw then
            DisplayTextToPlayer(Player(pid), 0, 0, "No ability in this slot.")
            return
        end
        local spec = SPELL_LAYOUT[raw]
        if not spec then
            DisplayTextToPlayer(Player(pid), 0, 0, "No ability in this slot.")
            return
        end
        if not hasAbility(u, raw) then
            DisplayTextToPlayer(Player(pid), 0, 0, "No ability in this slot.")
            return
        end

        if spec.orderType == "instant" then
            IssueImmediateOrderById(u, spec.orderId)
        elseif spec.orderType == "point" then
            IssuePointOrderById(u, spec.orderId, GetCameraTargetPositionX(), GetCameraTargetPositionY())
        elseif spec.orderType == "target" then
            -- simple fallback target behavior: use camera point like before
            IssuePointOrderById(u, spec.orderId, GetCameraTargetPositionX(), GetCameraTargetPositionY())
        else
            IssueImmediateOrderById(u, spec.orderId)
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        BAR_W = SLOT_COUNT*CELL_W + (SLOT_COUNT-1)*GAP_X + 2*PAD
        BAR_H = CELL_H + 2*PAD

        for pid=0, bj_MAX_PLAYERS-1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                if GetLocalPlayer() == Player(pid) then
                    ensureBar(pid)
                end
                local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]
                if pd and pd.hero then CustomSpellBar.BindHero(pid, pd.hero) end
            end
        end

        local tim = CreateTimer()
        TimerStart(tim, POLL_DT, true, function()
            for pid=0, bj_MAX_PLAYERS-1 do
                if GetPlayerController(Player(pid)) == MAP_CONTROL_USER and GetLocalPlayer() == Player(pid) then
                    if root[pid] then refresh(pid) end
                end
            end
        end)
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
