if Debug and Debug.beginFile then Debug.beginFile("PlayerMenu_SaveModule.lua") end
--==================================================
-- PlayerMenu_SaveModule.lua (compact version)
-- Smaller slot icons & tighter spacing.
-- Locked to PlayerMenu content box.
--==================================================

do
    PlayerMenu_SaveModule = PlayerMenu_SaveModule or {}
    _G.PlayerMenu_SaveModule = PlayerMenu_SaveModule

    local TEX_SLOT_BG  = "UI\\Widgets\\EscMenu\\Human\\human-inventory-slotfiller"
    local TEX_PORTRAIT = "ReplaceableTextures\\CommandButtons\\BTNPeasant.blp"

    -- layout inside the provided parent (content box)
    local GRID_COLS = 3
    local CELL_W    = 0.10       -- smaller cells
    local CELL_H    = 0.10
    local CELL_GAPX = 0.014
    local CELL_GAPY = 0.014
    local TOP_OFFSET= 0.075

    local SAVE_BTN_W = 0.20
    local SAVE_BTN_H = 0.040

    local cache = {} -- cache[pid] = {root, saveBtn, cells = {...}}

    local function makeCell(parent, x, y, idx)
        local cell = {}

        local box = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)
        BlzFrameSetSize(box, CELL_W, CELL_H)
        BlzFrameSetPoint(box, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, x, -y)
        BlzFrameSetTexture(box, TEX_SLOT_BG, 0, true)
        BlzFrameSetEnable(box, false)
        cell.box = box

        local icon = BlzCreateFrameByType("BACKDROP", "", box, "", 0)
        BlzFrameSetSize(icon, CELL_W * 0.6, CELL_H * 0.6) -- 60% scale icon
        BlzFrameSetPoint(icon, FRAMEPOINT_CENTER, box, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetTexture(icon, TEX_PORTRAIT, 0, true)
        cell.icon = icon

        local lbl = BlzCreateFrameByType("TEXT", "", box, "", 0)
        BlzFrameSetPoint(lbl, FRAMEPOINT_BOTTOMRIGHT, box, FRAMEPOINT_BOTTOMRIGHT, -0.004, 0.004)
        BlzFrameSetTextAlignment(lbl, TEXT_JUSTIFY_RIGHT, TEXT_JUSTIFY_BOTTOM)
        BlzFrameSetText(lbl, "Slot " .. tostring(idx))
        cell.lbl = lbl

        local btn = BlzCreateFrameByType("BUTTON", "", box, "", 0)
        BlzFrameSetAllPoints(btn, box)
        local trig = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trig, btn, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trig, function()
            DisplayTextToPlayer(GetLocalPlayer(), 0, 0, "Slot " .. tostring(idx) .. " clicked")
        end)
        cell.btn = btn

        return cell
    end

    local function ensure(pid, parent)
        local t = cache[pid]
        if t and t.root then return t end

        t = {}
        cache[pid] = t

        -- container anchored to provided parent
        local root = BlzCreateFrameByType("FRAME", "PM_SaveRoot", parent, "", 0)
        BlzFrameSetAllPoints(root, parent)
        t.root = root

        -- save current button at top middle
        local saveBtn = BlzCreateFrameByType("BUTTON", "", root, "", 0)
        BlzFrameSetSize(saveBtn, SAVE_BTN_W, SAVE_BTN_H)
        BlzFrameSetPoint(saveBtn, FRAMEPOINT_TOP, root, FRAMEPOINT_TOP, 0, -0.015)

        local saveBg = BlzCreateFrameByType("BACKDROP", "", saveBtn, "", 0)
        BlzFrameSetAllPoints(saveBg, saveBtn)
        BlzFrameSetTexture(saveBg, TEX_SLOT_BG, 0, true)

        local saveTxt = BlzCreateFrameByType("TEXT", "", saveBtn, "", 0)
        BlzFrameSetPoint(saveTxt, FRAMEPOINT_CENTER, saveBtn, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetTextAlignment(saveTxt, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(saveTxt, "Save Current")
        t.saveBtn = saveBtn

        local trigSave = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigSave, saveBtn, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigSave, function()
            local p   = GetLocalPlayer()
            local pid = GetPlayerId(p)
            if CharacterCreation_Adapter and CharacterCreation_Adapter.SaveSoul then
                CharacterCreation_Adapter.SaveSoul(pid, nil)
            else
                DisplayTextToPlayer(p, 0, 0, "Save system not wired")
            end
        end)

        -- grid
        t.cells = {}
        local x0 = 0.034
        local y0 = TOP_OFFSET + 0.060
        local col = 0
        local row = 0
        for i = 1, 9 do
            local x = x0 + col * (CELL_W + CELL_GAPX)
            local y = y0 + row * (CELL_H + CELL_GAPY)
            t.cells[i] = makeCell(root, x, y, i)
            col = col + 1
            if col == GRID_COLS then
                col = 0
                row = row + 1
            end
        end

        return t
    end

    --------------------------------------------------
    -- API
    --------------------------------------------------
    function PlayerMenu_SaveModule.ShowInto(pid, contentFrame)
        local t = ensure(pid, contentFrame)
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(t.root, true)
        end
    end

    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("PlayerMenu_SaveModule")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
