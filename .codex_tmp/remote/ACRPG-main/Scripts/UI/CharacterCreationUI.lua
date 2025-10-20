if Debug and Debug.beginFile then Debug.beginFile("CharacterCreation_UI.lua") end
--==================================================
-- CharacterCreation_UI.lua
-- • Builds the UI for "New Soul" and "Load Soul" buttons
-- • Style matched to TeleportShop (same button and backdrop style)
-- • Opens as part of the Bootflow sequence after loading bar
--==================================================

if not CharacterCreation_UI then CharacterCreation_UI = {} end
_G.CharacterCreation_UI = CharacterCreation_UI

do
    local BTN_TEX = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller"  -- Button texture (same as the shop)
    local BG_TEX  = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"  -- Background texture (same as the shop)

    local frameMenu = {}
    local trigNew   = {}
    local trigLoad  = {}

    --------------------------------------------------
    -- Helper: player data
    --------------------------------------------------
    local function PD(pid)
        PLAYER_DATA = PLAYER_DATA or {}
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end

    --------------------------------------------------
    -- UI Setup for Character Creation Menu
    --------------------------------------------------
    function CharacterCreation_UI.ShowMenu(pid)
        if frameMenu[pid] then
            if GetLocalPlayer() == Player(pid) then
                BlzFrameSetVisible(frameMenu[pid], true)  -- Only show for local player
            end
            return
        end

        -- Make sure only the local player is interacting with the UI
        local ui = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local root = BlzCreateFrameByType("BACKDROP", "CreateMenuRoot", ui, "", 0)
        BlzFrameSetSize(root, 0.30, 0.20)
        BlzFrameSetPoint(root, FRAMEPOINT_CENTER, ui, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetTexture(root, BG_TEX, 0, true)
        BlzFrameSetEnable(root, false)
        frameMenu[pid] = root

        --------------------------------------------------
        -- Button: New Soul (with properly sized hitbox)
        --------------------------------------------------
        local btnNew = BlzCreateFrameByType("GLUETEXTBUTTON", "BtnNewSoul", root, "ScriptDialogButton", 0)
        BlzFrameSetSize(btnNew, 0.24, 0.06)  -- Set button size to match the backdrop
        BlzFrameSetPoint(btnNew, FRAMEPOINT_CENTER, root, FRAMEPOINT_CENTER, 0, 0.03)
        BlzFrameSetLevel(btnNew, 10)  -- Ensure the button is above all other frames
        local bgNew = BlzCreateFrameByType("BACKDROP", "", btnNew, "", 0)
        BlzFrameSetAllPoints(bgNew, btnNew)
        BlzFrameSetTexture(bgNew, BTN_TEX, 0, true)
        local txtNew = BlzCreateFrameByType("TEXT", "", btnNew, "", 0)
        BlzFrameSetPoint(txtNew, FRAMEPOINT_CENTER, btnNew, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetTextAlignment(txtNew, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(txtNew, "New Soul")

        --------------------------------------------------
        -- Button: Load Soul (with properly sized hitbox)
        --------------------------------------------------
        local btnLoad = BlzCreateFrameByType("GLUETEXTBUTTON", "BtnLoadSoul", root, "ScriptDialogButton", 0)
        BlzFrameSetSize(btnLoad, 0.24, 0.06)  -- Set button size to match the backdrop
        BlzFrameSetPoint(btnLoad, FRAMEPOINT_CENTER, root, FRAMEPOINT_CENTER, 0, -0.04)
        BlzFrameSetLevel(btnLoad, 10)  -- Ensure the button is above all other frames
        local bgLoad = BlzCreateFrameByType("BACKDROP", "", btnLoad, "", 0)
        BlzFrameSetAllPoints(bgLoad, btnLoad)
        BlzFrameSetTexture(bgLoad, BTN_TEX, 0, true)
        local txtLoad = BlzCreateFrameByType("TEXT", "", btnLoad, "", 0)
        BlzFrameSetPoint(txtLoad, FRAMEPOINT_CENTER, btnLoad, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetTextAlignment(txtLoad, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(txtLoad, "Load Soul")

        --------------------------------------------------
        -- Button triggers
        --------------------------------------------------
        trigNew[pid] = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigNew[pid], btnNew, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigNew[pid], function()
            if GetLocalPlayer() == Player(pid) then
                BlzFrameSetVisible(frameMenu[pid], false)
            end
            -- For now: directly create soul
            if CharacterCreation and CharacterCreation.Begin then
                pcall(CharacterCreation.Begin, pid)
            end
        end)

        trigLoad[pid] = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigLoad[pid], btnLoad, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigLoad[pid], function()
            DisplayTextToPlayer(Player(pid), 0, 0, "Load Soul not yet implemented.")
        end)

        --------------------------------------------------
        -- Show for local player (checks if it’s the local player)
        --------------------------------------------------
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(root, true)
        end
    end

end

if Debug and Debug.endFile then Debug.endFile() end
