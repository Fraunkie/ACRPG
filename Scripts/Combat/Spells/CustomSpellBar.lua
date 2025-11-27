if Debug and Debug.beginFile then Debug.beginFile("CustomSpellBar.lua") end
--==================================================
-- CustomSpellBar.lua  (v1.3b, 2025-10-29)
-- Bottom-centered single row of 10 custom ability buttons
--  • Uses PlayerData[pid].loadout for slot contents (rawcodes)
--  • Click / hotkey triggers a RUNNER or ORDER_FALLBACK
--  • Per-slot cooldowns (timer-driven; no GetGameTime)
--  • WC3-safe (no percent), WORLD_FRAME parent; hover ring + tooltip
--  • Shows assigned icon even if the unit doesn't have the ability yet
--==================================================

if not CustomSpellBar then CustomSpellBar = {} end
_G.CustomSpellBar = CustomSpellBar

do
    --------------------------------------------------
    -- TUNABLES
    --------------------------------------------------
    local SLOT_COUNT   = 10
    local SCALE        = 0.80
    local BASE_CELL    = 0.040
    local CELL_W       = BASE_CELL * SCALE
    local CELL_H       = BASE_CELL * SCALE

    local BASE_GAP_X   = 0.005
    local GAP_X        = BASE_GAP_X * SCALE
    local PAD          = 0.004 * SCALE

    local BOTTOM_Y     = 0.0 * SCALE
    local ALIGN_X      = 0.20

    local TIP_W        = 0.16
    local TIP_H        = 0.05
    local TIP_PAD      = 0.006

    local SHOW_PLACEHOLDERS = true
    local EMPTY_ICON        = "war3mapImported\\SpellEmpty.blp"
    local BTN_BG            = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller"
    local BTN_MASK          = "UI\\Feedback\\AutocastButton.blp"

    local POLL_DT           = 0.25
    local CD_TICK           = 0.10

    --------------------------------------------------
    -- STATE
    --------------------------------------------------
    local root   = {}  -- pid -> bar root
    local slots  = {}  -- pid -> { [i] = {btn,icon,ring,tip,tipBg,abilRaw} }
    local hero   = {}  -- pid -> unit
    local cd     = {}  -- pid -> { [slot] = remaining_seconds }

    --------------------------------------------------
    -- MAPPINGS
    --------------------------------------------------
    local RUNNER = {}          -- raw -> function(unit) -> handled?
    local ORDER_FALLBACK = {}  -- raw -> orderId

    -- Per-ability cooldowns (seconds)
    local COOLDOWN = {
        [FourCC('A002')] = 4.0,   -- Spirit Burst
        --[FourCC('A0SV')] = 20.0,  -- Spirit Vortex
    }

    --------------------------------------------------
    -- HELPERS
    --------------------------------------------------
    local function toRaw(v) return (type(v)=="string") and FourCC(v) or v end
    local function abilId(v) return toRaw(v) end
    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end

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

    local function getPlayerLoadout(pid)
        _G.PlayerData = _G.PlayerData or {}
        _G.PlayerData[pid] = _G.PlayerData[pid] or {}
        _G.PlayerData[pid].loadout = _G.PlayerData[pid].loadout or {}
        return _G.PlayerData[pid].loadout
    end

    local function startCooldown(pid, slotIdx, duration)
        cd[pid] = cd[pid] or {}
        cd[pid][slotIdx] = duration
        local e = slots[pid] and slots[pid][slotIdx]
        if e then BlzFrameSetAlpha(e.icon, 100) end
    end

    local function isOnCooldown(pid, slotIdx)
        return cd[pid] and cd[pid][slotIdx] and cd[pid][slotIdx] > 0
    end

    --------------------------------------------------
    -- UI BUILD
    --------------------------------------------------
    local function ensureBar(pid)
        if root[pid] then return end

        local parent = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local r = BlzCreateFrameByType("FRAME", "SpellBarRoot"..pid, parent, "", 0)
        root[pid] = r
        local BAR_W = SLOT_COUNT*CELL_W + (SLOT_COUNT-1)*GAP_X + 2*PAD
        local BAR_H = CELL_H + 2*PAD
        BlzFrameSetSize(r, BAR_W, BAR_H)
        BlzFrameSetPoint(r, FRAMEPOINT_BOTTOM, parent, FRAMEPOINT_BOTTOM, ALIGN_X, BOTTOM_Y)
        BlzFrameSetLevel(r, 50)

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
                local e = slots[pid][i]
                local title = "Empty Slot"
                if e and e.abilRaw then
                    local nm = GetAbilityName(abilId(e.abilRaw)) or "Ability"
                    if isOnCooldown(pid, i) then
                        local secs = math.ceil(cd[pid][i] or 0)
                        nm = nm.."  ("..tostring(secs).."s)"
                    end
                    title = nm
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
    -- REFRESH (from PlayerData[pid].loadout)
    --------------------------------------------------
    local function refresh(pid)
        -- auto-bind hero if not already set
        if (not hero[pid]) and _G.PlayerData and PlayerData[pid] and validUnit(PlayerData[pid].hero) then
            hero[pid] = PlayerData[pid].hero
        end

        local u = hero[pid]
        local loadout = getPlayerLoadout(pid)

        for i=1, SLOT_COUNT do
            local e = slots[pid][i]
            if e then
                local raw = loadout[i]
                if raw then
                    local iconPath = BlzGetAbilityIcon(abilId(raw)) or EMPTY_ICON
                    BlzFrameSetTexture(e.icon, iconPath, 0, true)
                    BlzFrameSetAlpha(e.icon, isOnCooldown(pid, i) and 100 or 255)
                    e.abilRaw = toRaw(raw)
                else
                    BlzFrameSetTexture(e.icon, EMPTY_ICON, 0, true)
                    BlzFrameSetAlpha(e.icon, SHOW_PLACEHOLDERS and 120 or 20)
                    e.abilRaw = nil
                end
            end
        end
    end

    --------------------------------------------------
    -- PUBLIC API
    --------------------------------------------------
    function CustomSpellBar.BindHero(pid, u)
        hero[pid] = u
        if GetLocalPlayer() == Player(pid) then refresh(pid) end
    end

    function CustomSpellBar.Refresh(pid)
        if GetLocalPlayer() == Player(pid) then refresh(pid) end
    end

    function CustomSpellBar.SetSlot(pid, slotIdx, abilRaw)
        local loadout = getPlayerLoadout(pid)
        loadout[slotIdx] = toRaw(abilRaw)

        if GetLocalPlayer() == Player(pid) then
            local e = slots[pid] and slots[pid][slotIdx]
            if e then
                local iconPath = BlzGetAbilityIcon(abilId(abilRaw)) or EMPTY_ICON
                BlzFrameSetTexture(e.icon, iconPath, 0, true)
                BlzFrameSetAlpha(e.icon, isOnCooldown(pid, slotIdx) and 100 or 255)
                e.abilRaw = toRaw(abilRaw)
            end
        end

        local nm = GetAbilityName(abilId(abilRaw)) or tostring(abilRaw)
        DisplayTextToPlayer(Player(pid), 0, 0, "[Bar] Assigned "..nm.." to slot "..tostring(slotIdx))
    end

    function CustomSpellBar.ActivateSlot(pid, slotIndex)
        if GetLocalPlayer() ~= Player(pid) then return end
            
        local e = slots[pid] and slots[pid][slotIndex]
        if not e then
            DisplayTextToPlayer(Player(pid), 0, 0, "No ability in this slot.")
            return
        end

        local u = hero[pid]
        if not validUnit(u) then
            DisplayTextToPlayer(Player(pid), 0, 0, "No valid unit in this slot.")
            return
        end

        if isOnCooldown(pid, slotIndex) then
            local secs = math.ceil(cd[pid][slotIndex] or 0)
            DisplayTextToPlayer(Player(pid), 0, 0, "On cooldown: "..tostring(secs).."s")
            return
        end

        local raw = e.abilRaw
        if not raw then
            DisplayTextToPlayer(Player(pid), 0, 0, "No ability in this slot.")
            return
        end

        local key = toRaw(raw)

        local runner = RUNNER[key]
        if runner then
            local ok = false
            local status = pcall(function() ok = runner(u) or false end)
            if status and ok then
                local dur = COOLDOWN[key]
                if dur and dur > 0 then startCooldown(pid, slotIndex, dur) end
                return
            end
        end

        local orderId = ORDER_FALLBACK[key]
        if orderId then
            IssueImmediateOrderById(u, orderId)
            local dur = COOLDOWN[key]
            if dur and dur > 0 then startCooldown(pid, slotIndex, dur) end
            return
        end

        DisplayTextToPlayer(Player(pid), 0, 0, "No runner or order mapping for this ability.")
    end

    --------------------------------------------------
    -- INIT
    --------------------------------------------------
    OnInit.final(function()

        --------------------------------------------------
        --- Runners 
        --------------------------------------------------

        RUNNER[FourCC('A0EB')] = function(caster)
            print("RUNNER triggered for A0EB")  -- Debugging line to check if the runner is triggered
            if _G.Spell_EnergyBounce and Spell_EnergyBounce.Cast then
                local hero = hero[GetPlayerId(GetOwningPlayer(caster))]
                if hero then
                    print("Casting Energy Ball for hero: ", GetUnitName(caster))  -- Debug print
                    Spell_EnergyBounce.Cast(hero)
                    return true
                end
            end
            return false
        end




        RUNNER[FourCC('A002')] = function(caster)
            if _G.Spell_SoulBurst and Spell_SoulBurst.Cast then
                Spell_SoulBurst.Cast(caster)
                return true
            end
            return false
        end
        RUNNER[FourCC('A0SV')] = function(caster)
            if _G.Spell_SpiritVortex and Spell_SpiritVortex.Cast then
                Spell_SpiritVortex.Cast(caster)
                return true
            end
            return false
        end
        RUNNER[FourCC('A0CE')] = function(caster)
            print("RUNNER triggered for A0CE")  -- Debugging line to check if the runner is triggered
            if _G.Spell_KiBlast and Spell_KiBlast.Cast then
                local hero = hero[GetPlayerId(GetOwningPlayer(caster))]
                if hero then
                    print("Casting Continuous Energy Bullet for hero: ", GetUnitName(caster))  -- Debug print
                    Spell_KiBlast.Cast(hero)  -- Pass the hero to Cast function
                    return true
                end
            end
            return false
        end
        --------------------------------------------------
        --------------------------------------------------
       
        for pid=0, bj_MAX_PLAYERS-1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                if GetLocalPlayer() == Player(pid) then
                    ensureBar(pid)
                end
                local pd = _G.PlayerData and PlayerData[pid]
                if pd and pd.hero then CustomSpellBar.BindHero(pid, pd.hero) end
            end
        end

        -- Icon/ownership polling
        local tim = CreateTimer()
        TimerStart(tim, POLL_DT, true, function()
            for pid=0, bj_MAX_PLAYERS-1 do
                if GetPlayerController(Player(pid)) == MAP_CONTROL_USER
                and GetLocalPlayer() == Player(pid)
                and root[pid] then
                    refresh(pid)
                end
            end
        end)

        -- Global cooldown ticker
        local cdTimer = CreateTimer()
        TimerStart(cdTimer, CD_TICK, true, function()
            for pid=0, bj_MAX_PLAYERS-1 do
                if cd[pid] then
                    for i=1, SLOT_COUNT do
                        if cd[pid][i] and cd[pid][i] > 0 then
                            cd[pid][i] = cd[pid][i] - CD_TICK
                            if cd[pid][i] <= 0 then
                                cd[pid][i] = nil
                                local e = slots[pid] and slots[pid][i]
                                if e then BlzFrameSetAlpha(e.icon, 255) end
                            end
                        end
                    end
                end
            end
        end)
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
