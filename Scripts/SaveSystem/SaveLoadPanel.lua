if Debug and Debug.beginFile then Debug.beginFile("SaveLoadPanel.lua") end
--==================================================
-- SaveLoadPanel.lua
-- Renders a 3x3 slots grid plus "Save Current" button
-- into a provided container frame from PlayerMenu.
--==================================================

if not SaveLoadPanel then SaveLoadPanel = {} end
_G.SaveLoadPanel = SaveLoadPanel

do
    local TEX_CELL   = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local TEX_BTN_BG = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller"
    local TEX_ICON   = "ReplaceableTextures\\CommandButtons\\BTNHeroPaladin.blp"

    local GRID_COLS, GRID_ROWS = 3, 3
    local CELL_W, CELL_H       = 0.11, 0.11     -- smaller cells (about 60 percent of earlier)
    local CELL_PAD             = 0.012
    local ICON_W, ICON_H       = 0.060, 0.060   -- icon inside cell
    local TOP_PAD              = 0.070

    local per = {}  -- per[pid] = {root=..., cells={...}}

    local function wipeChildren(root)
        -- optional: nothing here; WC3 frames have no generic enumerate in Lua
        -- We just recreate a fresh root under the container each time.
    end

    local function mkBackdrop(parent, w, h, tex)
        local f = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)
        BlzFrameSetSize(f, w, h)
        BlzFrameSetTexture(f, tex, 0, true)
        return f
    end
    local function mkText(parent, text)
        local t = BlzCreateFrameByType("TEXT", "", parent, "", 0)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(t, text or "")
        return t
    end
    local function mkButton(parent, w, h, label)
        local b  = BlzCreateFrameByType("BUTTON", "", parent, "", 0)
        BlzFrameSetSize(b, w, h)
        local bg = BlzCreateFrameByType("BACKDROP", "", b, "", 0)
        BlzFrameSetAllPoints(bg, b)
        BlzFrameSetTexture(bg, TEX_BTN_BG, 0, true)
        local t  = mkText(b, label or "")
        BlzFrameSetPoint(t, FRAMEPOINT_CENTER, b, FRAMEPOINT_CENTER, 0, 0)
        return b
    end

    local function saveCurrent(pid)
        local hero = (_G.PlayerData and PlayerData.GetHero and PlayerData.GetHero(pid)) or nil
        if not hero or GetUnitTypeId(hero) == 0 then
            DisplayTextToPlayer(Player(pid), 0, 0, "No hero to save.")
            return
        end
        local SLS = rawget(_G, "SaveSystem")
        if SLS and SLS.SaveCurrent then
            pcall(SLS.SaveCurrent, pid)
        else
            DisplayTextToPlayer(Player(pid), 0, 0, "Saved (placeholder).")
        end
    end

    local function onClickSlot(pid, index)
        -- no auto-create; just try load if available
        local SLS = rawget(_G, "SaveSystem")
        if SLS and SLS.LoadSlot then
            pcall(SLS.LoadSlot, pid, index)
        else
            DisplayTextToPlayer(Player(pid), 0, 0, "Slot " .. tostring(index) .. " selected.")
        end
    end

    function SaveLoadPanel.Show(pid, container)
        -- rebuild a fresh root each call
        if per[pid] and per[pid].root then
            if GetLocalPlayer() == Player(pid) then
                BlzFrameSetVisible(per[pid].root, false)
            end
            per[pid] = nil
        end

        local root = mkBackdrop(container, 0.001, 0.001, TEX_CELL) -- tiny holder
        BlzFrameSetAllPoints(root, container)

        -- Save button at top center
        local btnSave = mkButton(root, 0.30, 0.045, "Save Current")
        BlzFrameSetPoint(btnSave, FRAMEPOINT_TOP, root, FRAMEPOINT_TOP, 0, -PAD or -0.012)
        local trigSave = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigSave, btnSave, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigSave, function() saveCurrent(pid) end)

        -- Grid start anchor
        local gridTop = BlzCreateFrameByType("FRAME", "", root, "", 0)
        BlzFrameSetSize(gridTop, 0.001, 0.001)
        BlzFrameSetPoint(gridTop, FRAMEPOINT_TOP, root, FRAMEPOINT_TOP, 0, -TOP_PAD)

        -- Build cells
        local cells = {}
        local index = 0
        for r = 1, GRID_ROWS do
            for c = 1, GRID_COLS do
                index = index + 1
                local cell = mkBackdrop(root, CELL_W, CELL_H, TEX_CELL)

                -- position
                local xOff = ((c - 1) * (CELL_W + CELL_PAD))
                local yOff = -((r - 1) * (CELL_H + CELL_PAD))
                BlzFrameSetPoint(cell, FRAMEPOINT_TOPLEFT, gridTop, FRAMEPOINT_TOPLEFT, xOff, yOff)

                -- icon
                local ico = mkBackdrop(cell, ICON_W, ICON_H, TEX_ICON)
                BlzFrameSetPoint(ico, FRAMEPOINT_CENTER, cell, FRAMEPOINT_CENTER, 0, 0)

                -- label
                local lbl = mkText(cell, "Slot " .. tostring(index))
                BlzFrameSetPoint(lbl, FRAMEPOINT_RIGHT, cell, FRAMEPOINT_RIGHT, -0.006, -0.034)

                -- click
                local b = BlzCreateFrameByType("BUTTON", "", cell, "", 0)
                BlzFrameSetAllPoints(b, cell)
                local trg = CreateTrigger()
                BlzTriggerRegisterFrameEvent(trg, b, FRAMEEVENT_CONTROL_CLICK)
                local slotIndex = index
                TriggerAddAction(trg, function() onClickSlot(pid, slotIndex) end)

                cells[index] = {cell=cell, icon=ico, label=lbl, button=b}
            end
        end

        per[pid] = {root=root, cells=cells}
        if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(root, true) end
    end
end

if Debug and Debug.endFile then Debug.endFile() end
