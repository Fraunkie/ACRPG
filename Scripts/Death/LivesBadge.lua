if Debug and Debug.beginFile then Debug.beginFile("LivesBadge.lua") end
--==================================================
-- LivesBadge.lua
-- Minimal lives HUD with toggle
--==================================================

if not LivesBadge then LivesBadge = {} end
_G.LivesBadge = LivesBadge

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local PANEL_BG = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local ICON     = "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"

    local W, H     = 0.102, 0.032
    local ICON_W   = 0.026
    local GAP      = 0.006

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local root  = {}
    local icon  = {}
    local text  = {}
    local shown = {}

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function ensure(pid)
        if root[pid] then return end
        local ui  = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local r   = BlzCreateFrameByType("BACKDROP", "LivesBadge_" .. pid, ui, "", 0)
        root[pid] = r

        BlzFrameSetSize(r, W, H)
        BlzFrameSetPoint(r, FRAMEPOINT_TOPLEFT, ui, FRAMEPOINT_TOPLEFT, 0.020, -0.040)
        BlzFrameSetTexture(r, PANEL_BG, 0, true)
        BlzFrameSetVisible(r, false)

        local ic = BlzCreateFrameByType("BACKDROP", "LivesBadgeIcon_" .. pid, r, "", 0)
        icon[pid] = ic
        BlzFrameSetSize(ic, ICON_W, ICON_W)
        BlzFrameSetPoint(ic, FRAMEPOINT_LEFT, r, FRAMEPOINT_LEFT, GAP, 0.0)
        BlzFrameSetTexture(ic, ICON, 0, true)

        local tx = BlzCreateFrameByType("TEXT", "LivesBadgeText_" .. pid, r, "", 0)
        text[pid] = tx
        BlzFrameSetScale(tx, 1.00)
        BlzFrameSetTextAlignment(tx, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetPoint(tx, FRAMEPOINT_LEFT, ic, FRAMEPOINT_RIGHT, GAP, 0.0)
        BlzFrameSetText(tx, "Lives 0 of 0")
    end

    local function setVisible(pid, vis)
        shown[pid] = vis and true or false
        if root[pid] and GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(root[pid], shown[pid])
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function LivesBadge.Update(pid, lives, maxLives)
        ensure(pid)
        local txt = "Lives " .. tostring(lives or 0) .. " of " .. tostring(maxLives or 0)
        if text[pid] and GetLocalPlayer() == Player(pid) then
            BlzFrameSetText(text[pid], txt)
        end
        if shown[pid] == nil then
            setVisible(pid, true)
        else
            setVisible(pid, shown[pid])
        end
    end

    function LivesBadge.Show(pid)
        ensure(pid)
        setVisible(pid, true)
    end

    function LivesBadge.Hide(pid)
        if not root[pid] then return end
        setVisible(pid, false)
    end

    --------------------------------------------------
    -- Chat toggle
    --------------------------------------------------
    local function reg(cmd, fn)
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(t, Player(i), cmd, false)
        end
        TriggerAddAction(t, function()
            fn(GetTriggerPlayer(), GetEventPlayerChatString())
        end)
    end

    reg("-livesui", function(who, msg)
        local pid = GetPlayerId(who)
        local tail = string.sub(msg or "", string.len("-livesui") + 2)
        local arg = string.lower(tail or "")
        if arg == "show" then
            LivesBadge.Show(pid)
            DisplayTextToPlayer(who, 0, 0, "Lives HUD shown")
        elseif arg == "hide" then
            LivesBadge.Hide(pid)
            DisplayTextToPlayer(who, 0, 0, "Lives HUD hidden")
        elseif arg == "toggle" then
            ensure(pid)
            local now = not shown[pid]
            setVisible(pid, now)
            DisplayTextToPlayer(who, 0, 0, now and "Lives HUD shown" or "Lives HUD hidden")
        else
            DisplayTextToPlayer(who, 0, 0, "Usage dash livesui show or hide or toggle")
        end
    end)

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    if OnInit and OnInit.final then
        OnInit.final(function()
            for pid = 0, bj_MAX_PLAYERS - 1 do
                if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                    ensure(pid)
                end
            end
        end)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
