if Debug and Debug.beginFile then Debug.beginFile("PlayerMenu_SaveModule.lua") end
--==================================================
-- PlayerMenu_SaveModule.lua
-- Renders a 3x3 slots grid inside the PlayerMenu content panel.
-- • Call: PlayerMenu_SaveModule.ShowInto(pid, contentFrame)
-- • Small cells, neat spacing, "Save Current" button at top
-- • No percent symbols anywhere
--==================================================

if not PlayerMenu_SaveModule then PlayerMenu_SaveModule = {} end
_G.PlayerMenu_SaveModule = PlayerMenu_SaveModule

do
    --------------------------------------------------
    -- Style / Layout
    --------------------------------------------------
    local TEX_BG_LIGHT = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local TEX_BTN      = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller"
    local TEX_ICON     = "ReplaceableTextures\\CommandButtons\\BTNHeroPaladin.blp"

    local GRID_COLS, GRID_ROWS = 3, 3
    local PAD_OUT   = 0.012       -- inner padding from content panel edges
    local PAD_CELL  = 0.010       -- gap between cells
    local CELL_W    = 0.11
    local CELL_H    = 0.11
    local ICON_W    = 0.060
    local ICON_H    = 0.060
    local SAVE_W    = 0.26
    local SAVE_H    = 0.045

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local INST = {}   -- INST[pid] = {root, cells = { {cell,icon,label,btn}... } }

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function mkBackdrop(parent, w, h, tex)
        local f = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)
        BlzFrameSetSize(f, w, h)
        BlzFrameSetTexture(f, tex, 0, true)
        return f
    end
    local function mkText(parent, s)
        local t = BlzCreateFrameByType("TEXT", "", parent, "", 0)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(t, s or "")
        return t
    end
    local function mkButton(parent, w, h, label)
        local b  = BlzCreateFrameByType("BUTTON", "", parent, "", 0)
        BlzFrameSetSize(b, w, h)
        local bg = BlzCreateFrameByType("BACKDROP", "", b, "", 0)
        BlzFrameSetAllPoints(bg, b)
        BlzFrameSetTexture(bg, TEX_BTN, 0, true)
        local t  = mkText(b, label or "")
        BlzFrameSetPoint(t, FRAMEPOINT_CENTER, b, FRAMEPOINT_CENTER, 0, 0)
        return b
    end

    local function getHero(pid)
        if _G.PlayerData and PlayerData.GetHero then return PlayerData.GetHero(pid) end
        if _G.PLAYER_DATA and PLAYER_DATA[pid] then return PLAYER_DATA[pid].hero end
        return nil
    end

    local function saveCurrent(pid)
        local u = getHero(pid)
        if not u or GetUnitTypeId(u) == 0 then
            DisplayTextToPlayer(Player(pid), 0, 0, "No hero to save.")
            return
        end
        local S = rawget(_G, "SaveSystem")
        if S and S.SaveCurrent then
            pcall(S.SaveCurrent, pid)
        else
            DisplayTextToPlayer(Player(pid), 0, 0, "Saved (placeholder).")
        end
    end

    local function onClickSlot(pid, index)
        local S = rawget(_G, "SaveSystem")
        if S and S.LoadSlot then
            pcall(S.LoadSlot, pid, index)
        else
            DisplayTextToPlayer(Player(pid), 0, 0, "Slot " .. tostring(index) .. " selected.")
        end
    end

    --------------------------------------------------
    -- Public
    --------------------------------------------------
    function PlayerMenu_SaveModule.ShowInto(pid, contentFrame)
        -- remove old instance (hide) and rebuild
        if INST[pid] and INST[pid].root then
            if GetLocalPlayer() == Player(pid) then
                BlzFrameSetVisible(INST[pid].root, false)
            end
            INST[pid] = nil
        end

        -- inner light panel sitting inside contentFrame with padding
        local inner = mkBackdrop(contentFrame, 0.001, 0.001, TEX_BG_LIGHT)
        BlzFrameSetPoint(inner, FRAMEPOINT_TOPLEFT,     contentFrame, FRAMEPOINT_TOPLEFT,     PAD_OUT, -PAD_OUT)
        BlzFrameSetPoint(inner, FRAMEPOINT_BOTTOMRIGHT, contentFrame, FRAMEPOINT_BOTTOMRIGHT, -PAD_OUT,  PAD_OUT)

        -- title
        local title = mkText(inner, "Save / Load")
        BlzFrameSetPoint(title, FRAMEPOINT_TOPLEFT, inner, FRAMEPOINT_TOPLEFT, 0.010, -0.010)

        -- "Save Current" button (top right)
        local btnSave = mkButton(inner, SAVE_W, SAVE_H, "Save Current")
        BlzFrameSetPoint(btnSave, FRAMEPOINT_TOPRIGHT, inner, FRAMEPOINT_TOPRIGHT, -0.010, -0.010)
        local trigS = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigS, btnSave, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigS, function() saveCurrent(pid) end)

        -- grid anchor
        local anchor = BlzCreateFrameByType("FRAME", "", inner, "", 0)
        BlzFrameSetSize(anchor, 0.001, 0.001)
        BlzFrameSetPoint(anchor, FRAMEPOINT_TOPLEFT, inner, FRAMEPOINT_TOPLEFT, 0.010, -0.070)

        -- build cells
        local cells = {}
        local idx = 0
        for r = 1, GRID_ROWS do
            for c = 1, GRID_COLS do
                idx = idx + 1
                local cell = mkBackdrop(inner, CELL_W, CELL_H, TEX_BG_LIGHT)
                local xOff = (c - 1) * (CELL_W + PAD_CELL)
                local yOff = -((r - 1) * (CELL_H + PAD_CELL))
                BlzFrameSetPoint(cell, FRAMEPOINT_TOPLEFT, anchor, FRAMEPOINT_TOPLEFT, xOff, yOff)

                local icon = mkBackdrop(cell, ICON_W, ICON_H, TEX_ICON)
                BlzFrameSetPoint(icon, FRAMEPOINT_CENTER, cell, FRAMEPOINT_CENTER, 0, 0)

                local lab = mkText(cell, "Slot " .. tostring(idx))
                BlzFrameSetPoint(lab, FRAMEPOINT_RIGHT, cell, FRAMEPOINT_RIGHT, -0.006, -0.034)

                -- click overlay
                local btn = BlzCreateFrameByType("BUTTON", "", cell, "", 0)
                BlzFrameSetAllPoints(btn, cell)
                local trg = CreateTrigger()
                BlzTriggerRegisterFrameEvent(trg, btn, FRAMEEVENT_CONTROL_CLICK)
                local slotIndex = idx
                TriggerAddAction(trg, function() onClickSlot(pid, slotIndex) end)

                cells[idx] = {cell=cell, icon=icon, label=lab, button=btn}
            end
        end

        INST[pid] = {root = inner, cells = cells}
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(inner, true)
        end
    end
end

if Debug and Debug.endFile then Debug.endFile() end
