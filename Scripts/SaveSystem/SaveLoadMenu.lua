if Debug and Debug.beginFile then Debug.beginFile("SaveLoadMenu.lua") end
--==================================================
-- SaveLoadMenu.lua
-- Independent Load / Save UI and logic
-- • 9 slots (3x3) + Save Current button
-- • Clicking a filled slot loads it
-- • Empty slot click just notifies
-- • Never creates new heroes
--==================================================

if not SaveLoadMenu then SaveLoadMenu = {} end
_G.SaveLoadMenu = SaveLoadMenu

do
    --------------------------------------------------
    -- Textures
    --------------------------------------------------
    local LIGHT_BG  = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local DARK_BG   = "ReplaceableTextures\\CameraMasks\\Black_mask.blp"
    local BTN_TEX   = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller"
    local SLOT_ICON = "ReplaceableTextures\\CommandButtons\\BTNHeroPaladin.blp"

    --------------------------------------------------
    -- Layout
    --------------------------------------------------
    local ROOT_W, ROOT_H = 0.42, 0.34
    local PAD            = 0.010
    local GRID_COLS      = 3
    local GRID_ROWS      = 3
    local CELL_W         = 0.115
    local CELL_H         = 0.115
    local GRID_X0        = 0.07   -- shift grid a bit right inside box
    local GRID_Y0        = -0.06  -- shift grid a bit down inside box
    local GRID_GAP       = 0.012
    local SAVE_BTN_W     = 0.18
    local SAVE_BTN_H     = 0.036

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local P = {}
    local function S(pid)
        P[pid] = P[pid] or {
            created=false, visible=false,
            root=nil, backLight=nil, panel=nil,
            grid={}, gridTrig={}, labels={},
            saveBtn=nil, saveTrig=nil,
            slots={}, -- [1..9] = {unitType, name}
        }
        return P[pid]
    end
    local function vis(pid, f, b)
        if f and GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(f, b) end
    end

    local function PD(pid)
        PLAYER_DATA = PLAYER_DATA or {}
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end
    local function heroOf(pid)
        local pd = PD(pid)
        if pd.hero and GetUnitTypeId(pd.hero) ~= 0 then return pd.hero end
        if _G.PlayerHero and PlayerHero[pid] and GetUnitTypeId(PlayerHero[pid]) ~= 0 then
            pd.hero = PlayerHero[pid]
            return pd.hero
        end
        return nil
    end
    local function readSpawnXY()
        if GameBalance then
            if GameBalance.SPAWN then
                return GameBalance.SPAWN.x or 0, GameBalance.SPAWN.y or 0
            end
            if GameBalance.HUB_COORDS and GameBalance.HUB_COORDS.SPAWN then
                return GameBalance.HUB_COORDS.SPAWN.x or 0, GameBalance.HUB_COORDS.SPAWN.y or 0
            end
        end
        return 0, 0
    end

    --------------------------------------------------
    -- UI helpers
    --------------------------------------------------
    local function makeBackdrop(parent, w, h, tex)
        local f = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)
        BlzFrameSetSize(f, w, h)
        BlzFrameSetTexture(f, tex, 0, true)
        return f
    end
    local function makeButton(parent, w, h, text)
        local b = BlzCreateFrameByType("BUTTON", "", parent, "", 0)
        BlzFrameSetSize(b, w, h)
        local bg = makeBackdrop(b, w, h, BTN_TEX)
        BlzFrameSetAllPoints(bg, b)
        local t = BlzCreateFrameByType("TEXT", "", b, "", 0)
        BlzFrameSetPoint(t, FRAMEPOINT_CENTER, b, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(t, text)
        return b
    end

    --------------------------------------------------
    -- Build once per player
    --------------------------------------------------
    function SaveLoadMenu.Create(pid)
        local s = S(pid); if s.created then return end
        local ui = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)

        -- Light outer background
        s.backLight = makeBackdrop(ui, ROOT_W + 0.02, ROOT_H + 0.02, LIGHT_BG)
        BlzFrameSetPoint(s.backLight, FRAMEPOINT_TOPLEFT, ui, FRAMEPOINT_TOPLEFT, 0.36, -0.12)
        BlzFrameSetEnable(s.backLight, false)

        -- Dark content panel on top
        s.root = makeBackdrop(s.backLight, ROOT_W, ROOT_H, DARK_BG)
        BlzFrameSetPoint(s.root, FRAMEPOINT_CENTER, s.backLight, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetEnable(s.root, false)

        -- Inner panel for grid
        s.panel = makeBackdrop(s.root, ROOT_W - PAD*2, ROOT_H - PAD*2, DARK_BG)
        BlzFrameSetPoint(s.panel, FRAMEPOINT_CENTER, s.root, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetAlpha(s.panel, 220)
        BlzFrameSetEnable(s.panel, false)

        -- Save Current button near top center
        s.saveBtn = makeButton(s.root, SAVE_BTN_W, SAVE_BTN_H, "Save Current")
        BlzFrameSetPoint(s.saveBtn, FRAMEPOINT_TOP, s.root, FRAMEPOINT_TOP, 0.00, -0.018)
        s.saveTrig = CreateTrigger()
        BlzTriggerRegisterFrameEvent(s.saveTrig, s.saveBtn, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(s.saveTrig, function()
            local hero = heroOf(pid)
            if not hero then
                DisplayTextToPlayer(Player(pid), 0, 0, "No hero to save.")
                return
            end
            local want = GetUnitTypeId(hero)
            -- first slot with same type, else first empty
            local idx, firstEmpty = nil, nil
            for i=1, GRID_COLS*GRID_ROWS do
                local slot = s.slots[i]
                if slot and slot.unitType == want then idx = i; break end
                if not slot and not firstEmpty then firstEmpty = i end
            end
            if not idx then idx = firstEmpty end
            if not idx then
                DisplayTextToPlayer(Player(pid), 0, 0, "All slots filled.")
                return
            end
            local name = GetPlayerName(Player(pid))
            s.slots[idx] = { unitType = want, name = name }
            DisplayTextToPlayer(Player(pid), 0, 0, "Saved to slot " .. tostring(idx))
            -- update label
            if s.labels[idx] and GetLocalPlayer() == Player(pid) then
                BlzFrameSetText(s.labels[idx], "Slot " .. tostring(idx))
            end
        end)

        -- Build 3x3 grid
        local idx = 1
        for r=1, GRID_ROWS do
            for c=1, GRID_COLS do
                local cell = makeBackdrop(s.panel, CELL_W, CELL_H, BTN_TEX)
                local offx = GRID_X0 + (c-1) * (CELL_W + GRID_GAP)
                local offy = GRID_Y0 - (r-1) * (CELL_H + GRID_GAP)
                BlzFrameSetPoint(cell, FRAMEPOINT_TOPLEFT, s.panel, FRAMEPOINT_TOPLEFT, offx, offy)

                local icon = makeBackdrop(cell, CELL_W * 0.55, CELL_H * 0.55, SLOT_ICON)
                BlzFrameSetPoint(icon, FRAMEPOINT_CENTER, cell, FRAMEPOINT_CENTER, 0, 0)

                local label = BlzCreateFrameByType("TEXT", "", cell, "", 0)
                BlzFrameSetPoint(label, FRAMEPOINT_RIGHT, cell, FRAMEPOINT_RIGHT, -0.006, -0.006)
                BlzFrameSetTextAlignment(label, TEXT_JUSTIFY_RIGHT, TEXT_JUSTIFY_MIDDLE)
                BlzFrameSetText(label, "Slot " .. tostring(idx))
                s.labels[idx] = label

                local btn = BlzCreateFrameByType("BUTTON", "", cell, "", 0)
                BlzFrameSetAllPoints(btn, cell)
                local trg = CreateTrigger()
                BlzTriggerRegisterFrameEvent(trg, btn, FRAMEEVENT_CONTROL_CLICK)
                TriggerAddAction(trg, function()
                    local slot = s.slots[idx]
                    if not slot then
                        DisplayTextToPlayer(Player(pid), 0, 0, "Empty slot.")
                        return
                    end
                    -- load: create hero of that type at spawn, select it, replace current
                    local x, y = readSpawnXY()
                    local newHero = CreateUnit(Player(pid), slot.unitType, x, y, 270.0)
                    PD(pid).hero = newHero
                    if _G.PlayerHero then PlayerHero[pid] = newHero end
                    if GetLocalPlayer() == Player(pid) then
                        PanCameraToTimed(x, y, 0.25)
                        ClearSelection()
                        SelectUnit(newHero, true)
                    end
                    DisplayTextToPlayer(Player(pid), 0, 0, "Loaded slot " .. tostring(idx))
                end)

                s.grid[idx] = cell
                s.gridTrig[idx] = trg
                idx = idx + 1
            end
        end

        vis(pid, s.backLight, false)
        vis(pid, s.root, false)
        vis(pid, s.panel, false)
        vis(pid, s.saveBtn, false)
        s.created = true
    end

    --------------------------------------------------
    -- Public
    --------------------------------------------------
    function SaveLoadMenu.Show(pid)
        local s = S(pid); if not s.created then SaveLoadMenu.Create(pid) end
        vis(pid, s.backLight, true)
        vis(pid, s.root, true)
        vis(pid, s.panel, true)
        vis(pid, s.saveBtn, true)
        for i=1, GRID_COLS*GRID_ROWS do vis(pid, s.grid[i], true) end
        s.visible = true
    end

    function SaveLoadMenu.Hide(pid)
        local s = S(pid); if not s.created then return end
        vis(pid, s.backLight, false)
        vis(pid, s.root, false)
        vis(pid, s.panel, false)
        vis(pid, s.saveBtn, false)
        for i=1, GRID_COLS*GRID_ROWS do vis(pid, s.grid[i], false) end
        s.visible = false
    end

    function SaveLoadMenu.Toggle(pid)
        local s = S(pid)
        if not s.created or not s.visible then
            SaveLoadMenu.Show(pid)
        else
            SaveLoadMenu.Hide(pid)
        end
    end

    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SaveLoadMenu")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
