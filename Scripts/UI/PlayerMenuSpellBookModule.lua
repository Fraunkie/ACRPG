if Debug and Debug.beginFile then Debug.beginFile("PlayerMenu_SpellbookModule.lua") end
--==================================================
-- PlayerMenu_SpellbookModule.lua (v4.1)
-- Pure Spellbook (Actives + Passives)
-- • Uses GameBalance.SPELL_UNLOCKS_BY_UNIT[unitTypeId]
-- • Unlock state read from PlayerData.Get(pid).knownspells
--      knownspells = { actives = { key = bool }, passives = { key = bool } }
--      key comes from entry.need.checkname
-- • Actives first, then Passives
-- • Pagination per section (Actives / Passives), page controls can be toggled
-- • Uses CustomTooltip.toc with its own g.spelltooltip
-- • Actives integrate with SlotPicker / CustomSpellBar
-- • ShowInto(pid, contentFrame) / Hide(pid) kept as public API
--==================================================

do
    PlayerMenu_SpellbookModule = PlayerMenu_SpellbookModule or {}
    _G.PlayerMenu_SpellbookModule = PlayerMenu_SpellbookModule

    if not g then g = {} end

    --------------------------------------------------
    -- Texture constants (all backgrounds centralized)
    --------------------------------------------------
    local TEX_BG_MAIN         = "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp"
    local TEX_BG_TOPBAR       = "UI\\Widgets\\EscMenu\\NightElf\\nightelf-options-menu-background.blp"
    local TEX_BG_SECTION      = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local TEX_BG_SECTION_HDR  = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local TEX_BG_CELL         = "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp"
    local TEX_BG_PAGEBAR      = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"

    local TEX_ICON_FALLBACK   = "ReplaceableTextures\\CommandButtons\\BTNSpellBookBLS.blp"
    local TEX_ICON_LOCK       = "ReplaceableTextures\\CommandButtons\\BTNLock.blp"

    -- Simple highlight border for buttons and tiles (you can swap this for a custom BLP later)
    local TEX_HIGHLIGHT       = "UI\\Widgets\\Glues\\GlueScreen-ButtonBackdrop.blp"

    --------------------------------------------------
    -- Layout constants
    --------------------------------------------------
    local PAD_OUT         = 0.010
    local PAD_IN          = 0.008
    local TOPBAR_H        = 0.024

    local SECTION_H       = 0.145
    local GAP_SECTIONS    = 0.012

    local GRID_COLS       = 4
    local GRID_ROWS       = 2
    local ICON_SIZE       = 0.032
    local CELL_W          = 0.080
    local CELL_H          = 0.060
    local CELL_GAP_X      = 0.006
    local CELL_GAP_Y      = 0.006

    local PAGEBAR_H       = 0.020
    local BUTTON_PAGE_W   = 0.018

    --------------------------------------------------
    -- Tooltip layout
    --------------------------------------------------
    local TOOLTIP_WIDTH   = 0.25
    local TOOLTIP_PAD_W   = 0.010
    local TOOLTIP_PAD_H   = 0.010

    --------------------------------------------------
    -- Per-player UI state
    --------------------------------------------------
    -- UI[pid] = {
    --   root,            -- the contentFrame we are attached to
    --   bgMain,
    --   topbar,
    --   txtTitle,
    --   btnToggleLocked,
    --   txtToggleLocked,
    --   hlToggleLocked,
    --   btnTogglePages,
    --   txtTogglePages,
    --   hlTogglePages,
    --   showLocked,
    --   showPages,
    --
    --   -- Actives
    --   secActive,
    --   secActiveHdr,
    --   txtActiveHdr,
    --   pageBarActive,
    --   btnActivePrev,
    --   btnActiveNext,
    --   txtActivePage,
    --   tilesActive = {},
    --   entriesActive = {},
    --   pageActive = 1,
    --   maxPageActive = 1,
    --
    --   -- Passives
    --   secPassive,
    --   secPassiveHdr,
    --   txtPassiveHdr,
    --   pageBarPassive,
    --   btnPassivePrev,
    --   btnPassiveNext,
    --   txtPassivePage,
    --   tilesPassive = {},
    --   entriesPassive = {},
    --   pagePassive = 1,
    --   maxPagePassive = 1,
    -- }
    local UI = {}

    --------------------------------------------------
    -- Small helpers
    --------------------------------------------------
    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function heroOf(pid)
        if _G.PlayerData and PlayerData.GetHero then
            local ok, hero = pcall(PlayerData.GetHero, pid)
            if ok and validUnit(hero) then
                return hero
            end
        end
        if _G.PLAYER_DATA and PLAYER_DATA[pid] and validUnit(PLAYER_DATA[pid].hero) then
            return PLAYER_DATA[pid].hero
        end
        if _G.PlayerHero and validUnit(PlayerHero[pid]) then
            return PlayerHero[pid]
        end
        return nil
    end

    local function four(id)
        if type(id) == "number" then
            return id
        end
        if type(id) == "string" then
            return FourCC(id)
        end
        return 0
    end

    local function getSpellUnlocksForUnit(unitTypeId)
        local GB = rawget(_G, "GameBalance")
        if not GB then
            return {}
        end

        local perUnit = (GB.GetSpellUnlocksByUnit and GB.GetSpellUnlocksByUnit()) or GB.SPELL_UNLOCKS_BY_UNIT
        if not perUnit then
            return {}
        end

        return perUnit[unitTypeId] or {}
    end

    local function isPassiveEntry(entry)
        if not entry then
            return false
        end
        if entry.type == "passive" then
            return true
        end
        if entry.flags and type(entry.flags) == "table" then
            for _, f in ipairs(entry.flags) do
                if f == "passive" then
                    return true
                end
            end
        end
        return false
    end

    local function getKnownTables(pid)
        if not _G.PlayerData or not PlayerData.Get then
            return nil
        end
        local pd = PlayerData.Get(pid)
        pd.knownspells = pd.knownspells or { passives = {}, actives = {} }
        pd.knownspells.passives = pd.knownspells.passives or {}
        pd.knownspells.actives  = pd.knownspells.actives or {}
        return pd.knownspells
    end

    local function isSpellKnown(pid, entry)
        local need = entry.need or {}
        local checkname = need.checkname
        if not checkname or checkname == "" then
            return false
        end

        local known = getKnownTables(pid)
        if not known then
            return false
        end

        local bucket
        if isPassiveEntry(entry) then
            bucket = known.passives
        else
            bucket = known.actives
        end

        if not bucket then
            return false
        end

        local val = bucket[checkname]
        if val == nil then
            return false
        end
        return val == true
    end

    --------------------------------------------------
    -- Spellbook-specific tooltip (g.spelltooltip)
    --------------------------------------------------
    local function getSpellTooltip()
        if g.spelltooltip and g.spelltooltip.box then
            return g.spelltooltip.box, g.spelltooltip.title, g.spelltooltip.text
        end

        BlzLoadTOCFile("CustomTooltip.toc")
        local parent = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local box   = BlzCreateFrame("CustomTooltip", parent, 0, 0)
        local title = BlzGetFrameByName("CustomTooltipTitle", 0)
        local text  = BlzGetFrameByName("CustomTooltipValue", 0)

        BlzFrameSetLevel(box, 100)
        BlzFrameSetVisible(box, false)

        g.spelltooltip = {
            box   = box,
            title = title,
            text  = text,
        }
        return box, title, text
    end

    local function showTooltipFor(pid, headline, body, anchor)
        if not anchor then
            return
        end

        local box, title, text = getSpellTooltip()
        if not box or not text then
            return
        end

        if GetLocalPlayer() ~= Player(pid) then
            return
        end

        headline = headline or ""
        body     = body or ""

        BlzFrameSetText(title, headline)
        BlzFrameSetText(text,  body)

        -- Constrain text width so it wraps horizontally instead of vertical letters
        BlzFrameSetSize(text, TOOLTIP_WIDTH, 0.0)
        local textH = BlzFrameGetHeight(text)
        local boxW = TOOLTIP_WIDTH + TOOLTIP_PAD_W * 2
        local boxH = textH + TOOLTIP_PAD_H * 2

        BlzFrameSetSize(box, boxW, boxH)

        BlzFrameClearAllPoints(box)
        BlzFrameSetPoint(
            box,
            FRAMEPOINT_BOTTOMLEFT,
            anchor,
            FRAMEPOINT_TOPLEFT,
            0.0,
            0.010
        )

        BlzFrameSetVisible(box, true)
    end

    local function hideTooltipFor(pid)
        local t = g.spelltooltip
        if not t or not t.box then
            return
        end
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(t.box, false)
        end
    end

    --------------------------------------------------
    -- Tile helpers
    --------------------------------------------------
    local function clearTiles(list)
        for i = 1, #list do
            local tile = list[i]
            if tile and tile.root then
                BlzFrameSetVisible(tile.root, false)
                BlzDestroyFrame(tile.root)
            end
        end
        for i = 1, #list do
            list[i] = nil
        end
    end

    local function setTilesVisible(list, flag)
        for i = 1, #list do
            local tile = list[i]
            if tile and tile.root then
                BlzFrameSetVisible(tile.root, flag)
            end
        end
    end

    local function setStaticVisible(ui, flag)
        if not ui then
            return
        end
        local frames = {
            ui.bgMain,
            ui.topbar,
            ui.secActive,
            ui.secActiveHdr,
            ui.pageBarActive,
            ui.secPassive,
            ui.secPassiveHdr,
            ui.pageBarPassive,
        }
        for i = 1, #frames do
            local f = frames[i]
            if f then
                BlzFrameSetVisible(f, flag)
            end
        end
    end

    --------------------------------------------------
    -- Tooltip text builder for an entry
    -- Uses entry.tooltip if present:
    --   tooltip = { header, title, description, requirements, damage }
    --------------------------------------------------
    local function buildTooltipText(abilId, entry)
        local tooltip = entry.tooltip or {}
        local headline = tooltip.header or entry.name or "Ability"

        local lines = {}

        if tooltip.title and tooltip.title ~= "" then
            lines[#lines+1] = tooltip.title
        end

        if tooltip.description and tooltip.description ~= "" then
            lines[#lines+1] = tooltip.description
        end

        local need = entry.need or {}
        local reqLine = tooltip.requirements

        if not reqLine or reqLine == "" then
            local reqParts = {}

            if need.pl_min then
                reqParts[#reqParts+1] = "Power Level " .. tostring(need.pl_min)
            end
            if need.sl_min then
                reqParts[#reqParts+1] = "Soul Level " .. tostring(need.sl_min)
            end
            if need.role then
                reqParts[#reqParts+1] = "Role: " .. tostring(need.role)
            end
            if need.family then
                reqParts[#reqParts+1] = "Family: " .. tostring(need.family)
            end

            if #reqParts > 0 then
                reqLine = "[" .. table.concat(reqParts, ", ") .. "]"
            end
        end

        if reqLine and reqLine ~= "" then
            lines[#lines+1] = reqLine
        end

        if tooltip.damage and tooltip.damage ~= "" then
            lines[#lines+1] = tooltip.damage
        end

        if #lines == 0 then
            if isPassiveEntry(entry) then
                lines[#lines+1] = "Passive ability."
            else
                lines[#lines+1] = "Active ability."
            end
        end

        local body = table.concat(lines, "\n\n")
        return headline, body
    end

    --------------------------------------------------
    -- Section rebuilds
    --------------------------------------------------
    local function rebuildSection(pid, sectionKey)
        local ui = UI[pid]
        if not ui then
            return
        end

        local isActive = (sectionKey == "active")
        local secFrame, pageBar, tiles, entries, page, maxPage

        local root = ui.root
        if not root then
            return
        end

        local itemsPerPage = GRID_COLS * GRID_ROWS

        if isActive then
            secFrame = ui.secActive
            pageBar  = ui.pageBarActive
            tiles    = ui.tilesActive
            entries  = ui.entriesActive
            page     = ui.pageActive
            maxPage  = ui.maxPageActive
        else
            secFrame = ui.secPassive
            pageBar  = ui.pageBarPassive
            tiles    = ui.tilesPassive
            entries  = ui.entriesPassive
            page     = ui.pagePassive
            maxPage  = ui.maxPagePassive
        end

        clearTiles(tiles)

        if not secFrame then
            return
        end

        local startIndex = (page - 1) * itemsPerPage + 1

        local idx = 0
        local rowStartY = - (TOPBAR_H + PAD_IN)

        if not isActive then
            -- passives sit below actives
            rowStartY = rowStartY - (SECTION_H + GAP_SECTIONS)
        end

        for row = 1, GRID_ROWS do
            for col = 1, GRID_COLS do
                idx = idx + 1
                local listIndex = startIndex + idx - 1
                local entry = entries[listIndex]
                if not entry then
                    goto continue
                end

                local abilId = four(entry.abil or 0)
                local known  = isSpellKnown(pid, entry)

                if not ui.showLocked and not known then
                    goto continue
                end

                local cell = BlzCreateFrameByType("BACKDROP", "SB_Cell", root, "", 0)
                BlzFrameSetSize(cell, CELL_W, CELL_H)
                BlzFrameSetTexture(cell, TEX_BG_CELL, 0, true)
                BlzFrameSetLevel(cell, 35)

                local offsetX = PAD_OUT + PAD_IN + (col - 1) * (CELL_W + CELL_GAP_X)
                local offsetY = rowStartY - (row - 1) * (CELL_H + CELL_GAP_Y)

                BlzFrameSetPoint(
                    cell,
                    FRAMEPOINT_TOPLEFT,
                    root,
                    FRAMEPOINT_TOPLEFT,
                    offsetX,
                    offsetY
                )

                local btn = BlzCreateFrameByType("BUTTON", "", cell, "", 0)
                BlzFrameSetPoint(btn, FRAMEPOINT_TOPLEFT, cell, FRAMEPOINT_TOPLEFT, PAD_IN, -PAD_IN)
                BlzFrameSetSize(btn, ICON_SIZE, ICON_SIZE)
                BlzFrameSetLevel(btn, 36)

                -- Icon
                local icon = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
                BlzFrameSetAllPoints(icon, btn)
                local ipath = entry.icon or BlzGetAbilityIcon(abilId)
                if not ipath or ipath == "" then
                    ipath = TEX_ICON_FALLBACK
                end
                BlzFrameSetTexture(icon, ipath, 0, true)

                -- Highlight on tile
                local hl = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
                BlzFrameSetAllPoints(hl, btn)
                BlzFrameSetTexture(hl, TEX_HIGHLIGHT, 0, true)
                BlzFrameSetLevel(hl, 37)
                BlzFrameSetAlpha(hl, 180)
                BlzFrameSetVisible(hl, false)

                -- Label
                local lbl = BlzCreateFrameByType("TEXT", "", cell, "", 0)
                BlzFrameSetPoint(lbl, FRAMEPOINT_BOTTOMLEFT, cell, FRAMEPOINT_BOTTOMLEFT, PAD_IN, PAD_IN)
                BlzFrameSetTextAlignment(lbl, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_BOTTOM)
                if isPassiveEntry(entry) then
                    if known then
                        BlzFrameSetText(lbl, "Passive")
                    else
                        BlzFrameSetText(lbl, "Passive (locked)")
                    end
                else
                    if known then
                        BlzFrameSetText(lbl, "Active")
                    else
                        BlzFrameSetText(lbl, "Active (locked)")
                    end
                end
                BlzFrameSetLevel(lbl, 38)

                -- Lock icon
                local lock = BlzCreateFrameByType("BACKDROP", "", cell, "", 0)
                BlzFrameSetSize(lock, 0.020, 0.020)
                BlzFrameSetPoint(lock, FRAMEPOINT_CENTER, cell, FRAMEPOINT_CENTER, 0.0, 0.0)
                BlzFrameSetTexture(lock, TEX_ICON_LOCK, 0, true)
                BlzFrameSetLevel(lock, 39)
                BlzFrameSetVisible(lock, (not known) and ui.showLocked)

                local headline, body = buildTooltipText(abilId, entry)

                -- Hover: tooltip + highlight
                local trigIn  = CreateTrigger()
                local trigOut = CreateTrigger()
                BlzTriggerRegisterFrameEvent(trigIn,  btn, FRAMEEVENT_MOUSE_ENTER)
                BlzTriggerRegisterFrameEvent(trigOut, btn, FRAMEEVENT_MOUSE_LEAVE)

                TriggerAddAction(trigIn, function()
                    BlzFrameSetVisible(hl, true)
                    showTooltipFor(pid, headline, body, cell)
                end)
                TriggerAddAction(trigOut, function()
                    BlzFrameSetVisible(hl, false)
                    hideTooltipFor(pid)
                end)

                -- Click: slot picker for actives
                local trigClick = CreateTrigger()
                BlzTriggerRegisterFrameEvent(trigClick, btn, FRAMEEVENT_CONTROL_CLICK)
                TriggerAddAction(trigClick, function()
                    if isPassiveEntry(entry) then
                        DisplayTextToPlayer(Player(pid), 0, 0, "Passive ability cannot be placed on the bar.")
                        return
                    end
                    if not known then
                        DisplayTextToPlayer(Player(pid), 0, 0, "Ability is locked. Meet the requirements first.")
                        return
                    end

                    if not _G.SlotPicker or not SlotPicker.Show then
                        DisplayTextToPlayer(Player(pid), 0, 0, "[Spellbook] Slot picker is not available.")
                        return
                    end

                    SlotPicker.Show(pid, root, cell, function(slotIdx)
                        if _G.SlotPicker and SlotPicker.AssignSlot then
                            SlotPicker.AssignSlot(pid, slotIdx, abilId)
                        elseif _G.CustomSpellBar and CustomSpellBar.SetSlot then
                            CustomSpellBar.SetSlot(pid, slotIdx, abilId)
                            if CustomSpellBar.Refresh then
                                CustomSpellBar.Refresh(pid)
                            end
                        end
                    end)
                end)

                tiles[#tiles+1] = {
                    root      = cell,
                    button    = btn,
                    icon      = icon,
                    label     = lbl,
                    lock      = lock,
                    highlight = hl,
                }

                ::continue::
            end
        end

        if not pageBar then
            return
        end

        local showPageBar = ui.showPages and (maxPage > 1)
        BlzFrameSetVisible(pageBar, showPageBar)
    end

    --------------------------------------------------
    -- Full rebuild (split entries into actives/passives)
    --------------------------------------------------
    local function rebuildAll(pid)
        local ui = UI[pid]
        if not ui or not ui.root then
            return
        end

        clearTiles(ui.tilesActive)
        clearTiles(ui.tilesPassive)

        ui.entriesActive  = {}
        ui.entriesPassive = {}

        local hero = heroOf(pid)
        if not validUnit(hero) then
            return
        end

        local unitTypeId = GetUnitTypeId(hero)
        local list = getSpellUnlocksForUnit(unitTypeId)

        for i = 1, #list do
            local entry = list[i]
            if entry then
                if isPassiveEntry(entry) then
                    ui.entriesPassive[#ui.entriesPassive+1] = entry
                else
                    ui.entriesActive[#ui.entriesActive+1] = entry
                end
            end
        end

        local itemsPerPage = GRID_COLS * GRID_ROWS

        ui.maxPageActive  = math.max(1, math.ceil(#ui.entriesActive  / itemsPerPage))
        ui.maxPagePassive = math.max(1, math.ceil(#ui.entriesPassive / itemsPerPage))

        if ui.pageActive > ui.maxPageActive then
            ui.pageActive = ui.maxPageActive
        end
        if ui.pagePassive > ui.maxPagePassive then
            ui.pagePassive = ui.maxPagePassive
        end

        if ui.txtActivePage then
            local txt = tostring(ui.pageActive) .. " / " .. tostring(ui.maxPageActive)
            BlzFrameSetText(ui.txtActivePage, txt)
        end
        if ui.txtPassivePage then
            local txt = tostring(ui.pagePassive) .. " / " .. tostring(ui.maxPagePassive)
            BlzFrameSetText(ui.txtPassivePage, txt)
        end

        rebuildSection(pid, "active")
        rebuildSection(pid, "passive")
    end

    --------------------------------------------------
    -- Top bar and sections
    --------------------------------------------------
    local function buildStaticUI(pid, contentFrame)
        local ui = UI[pid]

        ui.root = contentFrame

        ui.bgMain = BlzCreateFrameByType("BACKDROP", "SB_MainBG", ui.root, "", 0)
        BlzFrameSetAllPoints(ui.bgMain, ui.root)
        BlzFrameSetTexture(ui.bgMain, TEX_BG_MAIN, 0, true)
        BlzFrameSetLevel(ui.bgMain, 30)

        ui.topbar = BlzCreateFrameByType("BACKDROP", "SB_Topbar", ui.root, "", 0)
        BlzFrameSetPoint(ui.topbar, FRAMEPOINT_TOPLEFT,  ui.root, FRAMEPOINT_TOPLEFT,  PAD_OUT, -PAD_OUT)
        BlzFrameSetPoint(ui.topbar, FRAMEPOINT_TOPRIGHT, ui.root, FRAMEPOINT_TOPRIGHT, -PAD_OUT, -PAD_OUT)
        BlzFrameSetSize(ui.topbar, 0.10, TOPBAR_H)
        BlzFrameSetTexture(ui.topbar, TEX_BG_TOPBAR, 0, true)
        BlzFrameSetLevel(ui.topbar, 31)

        ui.txtTitle = BlzCreateFrameByType("TEXT", "SB_Title", ui.topbar, "", 0)
        BlzFrameSetPoint(ui.txtTitle, FRAMEPOINT_LEFT, ui.topbar, FRAMEPOINT_LEFT, PAD_IN, 0.0)
        BlzFrameSetTextAlignment(ui.txtTitle, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(ui.txtTitle, "Spellbook")
        BlzFrameSetLevel(ui.txtTitle, 32)

        -- Toggle locked
        ui.btnToggleLocked = BlzCreateFrameByType("BUTTON", "SB_ToggleLocked", ui.topbar, "", 0)
        BlzFrameSetSize(ui.btnToggleLocked, 0.100, TOPBAR_H - 0.004)
        BlzFrameSetPoint(ui.btnToggleLocked, FRAMEPOINT_RIGHT, ui.topbar, FRAMEPOINT_RIGHT, -0.010, 0.0)
        BlzFrameSetLevel(ui.btnToggleLocked, 32)

        local bgToggleLocked = BlzCreateFrameByType("BACKDROP", "", ui.btnToggleLocked, "", 0)
        BlzFrameSetAllPoints(bgToggleLocked, ui.btnToggleLocked)
        BlzFrameSetTexture(bgToggleLocked, TEX_BG_SECTION_HDR, 0, true)

        ui.txtToggleLocked = BlzCreateFrameByType("TEXT", "", ui.btnToggleLocked, "", 0)
        BlzFrameSetAllPoints(ui.txtToggleLocked, ui.btnToggleLocked)
        BlzFrameSetTextAlignment(ui.txtToggleLocked, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(ui.txtToggleLocked, "Show all")
        BlzFrameSetLevel(ui.txtToggleLocked, 33)

        ui.hlToggleLocked = BlzCreateFrameByType("BACKDROP", "", ui.btnToggleLocked, "", 0)
        BlzFrameSetAllPoints(ui.hlToggleLocked, ui.btnToggleLocked)
        BlzFrameSetTexture(ui.hlToggleLocked, TEX_HIGHLIGHT, 0, true)
        BlzFrameSetLevel(ui.hlToggleLocked, 34)
        BlzFrameSetAlpha(ui.hlToggleLocked, 180)
        BlzFrameSetVisible(ui.hlToggleLocked, false)

        -- Toggle pages
        ui.btnTogglePages = BlzCreateFrameByType("BUTTON", "SB_TogglePages", ui.topbar, "", 0)
        BlzFrameSetSize(ui.btnTogglePages, 0.090, TOPBAR_H - 0.004)
        BlzFrameSetPoint(ui.btnTogglePages, FRAMEPOINT_RIGHT, ui.btnToggleLocked, FRAMEPOINT_LEFT, -0.006, 0.0)
        BlzFrameSetLevel(ui.btnTogglePages, 32)

        local bgTogglePages = BlzCreateFrameByType("BACKDROP", "", ui.btnTogglePages, "", 0)
        BlzFrameSetAllPoints(bgTogglePages, ui.btnTogglePages)
        BlzFrameSetTexture(bgTogglePages, TEX_BG_SECTION_HDR, 0, true)

        ui.txtTogglePages = BlzCreateFrameByType("TEXT", "", ui.btnTogglePages, "", 0)
        BlzFrameSetAllPoints(ui.txtTogglePages, ui.btnTogglePages)
        BlzFrameSetTextAlignment(ui.txtTogglePages, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(ui.txtTogglePages, "Pages on")
        BlzFrameSetLevel(ui.txtTogglePages, 33)

        ui.hlTogglePages = BlzCreateFrameByType("BACKDROP", "", ui.btnTogglePages, "", 0)
        BlzFrameSetAllPoints(ui.hlTogglePages, ui.btnTogglePages)
        BlzFrameSetTexture(ui.hlTogglePages, TEX_HIGHLIGHT, 0, true)
        BlzFrameSetLevel(ui.hlTogglePages, 34)
        BlzFrameSetAlpha(ui.hlTogglePages, 180)
        BlzFrameSetVisible(ui.hlTogglePages, false)

        -- Active section
        ui.secActive = BlzCreateFrameByType("BACKDROP", "SB_ActiveSection", ui.root, "", 0)
        BlzFrameSetPoint(ui.secActive, FRAMEPOINT_TOPLEFT,  ui.root, FRAMEPOINT_TOPLEFT,  PAD_OUT, - (PAD_OUT + TOPBAR_H + PAD_IN))
        BlzFrameSetPoint(ui.secActive, FRAMEPOINT_TOPRIGHT, ui.root, FRAMEPOINT_TOPRIGHT, -PAD_OUT, - (PAD_OUT + TOPBAR_H + PAD_IN))
        BlzFrameSetSize(ui.secActive, 0.10, SECTION_H)
        BlzFrameSetTexture(ui.secActive, TEX_BG_SECTION, 0, true)
        BlzFrameSetLevel(ui.secActive, 31)

        ui.secActiveHdr = BlzCreateFrameByType("BACKDROP", "SB_ActiveHdr", ui.secActive, "", 0)
        BlzFrameSetPoint(ui.secActiveHdr, FRAMEPOINT_TOPLEFT,  ui.secActive, FRAMEPOINT_TOPLEFT,  PAD_IN, -PAD_IN)
        BlzFrameSetPoint(ui.secActiveHdr, FRAMEPOINT_TOPRIGHT, ui.secActive, FRAMEPOINT_TOPRIGHT, -PAD_IN, -PAD_IN)
        BlzFrameSetSize(ui.secActiveHdr, 0.10, 0.018)
        BlzFrameSetTexture(ui.secActiveHdr, TEX_BG_SECTION_HDR, 0, true)
        BlzFrameSetLevel(ui.secActiveHdr, 32)

        ui.txtActiveHdr = BlzCreateFrameByType("TEXT", "SB_ActiveHdrText", ui.secActiveHdr, "", 0)
        BlzFrameSetAllPoints(ui.txtActiveHdr, ui.secActiveHdr)
        BlzFrameSetTextAlignment(ui.txtActiveHdr, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(ui.txtActiveHdr, "Active Spells")
        BlzFrameSetLevel(ui.txtActiveHdr, 33)

        ui.pageBarActive = BlzCreateFrameByType("BACKDROP", "SB_ActivePageBar", ui.secActive, "", 0)
        BlzFrameSetPoint(ui.pageBarActive, FRAMEPOINT_BOTTOMLEFT, ui.secActive, FRAMEPOINT_BOTTOMLEFT, PAD_IN, PAD_IN)
        BlzFrameSetPoint(ui.pageBarActive, FRAMEPOINT_BOTTOMRIGHT, ui.secActive, FRAMEPOINT_BOTTOMRIGHT, -PAD_IN, PAD_IN)
        BlzFrameSetSize(ui.pageBarActive, 0.10, PAGEBAR_H)
        BlzFrameSetTexture(ui.pageBarActive, TEX_BG_PAGEBAR, 0, true)
        BlzFrameSetLevel(ui.pageBarActive, 32)

        ui.btnActivePrev = BlzCreateFrameByType("BUTTON", "SB_ActivePrev", ui.pageBarActive, "", 0)
        BlzFrameSetSize(ui.btnActivePrev, BUTTON_PAGE_W, PAGEBAR_H - 0.004)
        BlzFrameSetPoint(ui.btnActivePrev, FRAMEPOINT_LEFT, ui.pageBarActive, FRAMEPOINT_LEFT, PAD_IN, 0.0)
        BlzFrameSetLevel(ui.btnActivePrev, 33)

        local bgAPrev = BlzCreateFrameByType("BACKDROP", "", ui.btnActivePrev, "", 0)
        BlzFrameSetAllPoints(bgAPrev, ui.btnActivePrev)
        BlzFrameSetTexture(bgAPrev, TEX_BG_SECTION_HDR, 0, true)

        local txtAPrev = BlzCreateFrameByType("TEXT", "", ui.btnActivePrev, "", 0)
        BlzFrameSetAllPoints(txtAPrev, ui.btnActivePrev)
        BlzFrameSetTextAlignment(txtAPrev, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(txtAPrev, "<")
        BlzFrameSetLevel(txtAPrev, 34)

        ui.btnActiveNext = BlzCreateFrameByType("BUTTON", "SB_ActiveNext", ui.pageBarActive, "", 0)
        BlzFrameSetSize(ui.btnActiveNext, BUTTON_PAGE_W, PAGEBAR_H - 0.004)
        BlzFrameSetPoint(ui.btnActiveNext, FRAMEPOINT_RIGHT, ui.pageBarActive, FRAMEPOINT_RIGHT, -PAD_IN, 0.0)
        BlzFrameSetLevel(ui.btnActiveNext, 33)

        local bgANext = BlzCreateFrameByType("BACKDROP", "", ui.btnActiveNext, "", 0)
        BlzFrameSetAllPoints(bgANext, ui.btnActiveNext)
        BlzFrameSetTexture(bgANext, TEX_BG_SECTION_HDR, 0, true)

        ui.txtActivePage = BlzCreateFrameByType("TEXT", "SB_ActivePageText", ui.pageBarActive, "", 0)
        BlzFrameSetPoint(ui.txtActivePage, FRAMEPOINT_CENTER, ui.pageBarActive, FRAMEPOINT_CENTER, 0.0, 0.0)
        BlzFrameSetTextAlignment(ui.txtActivePage, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(ui.txtActivePage, "1 / 1")
        BlzFrameSetLevel(ui.txtActivePage, 34)

        -- Passive section (below active)
        ui.secPassive = BlzCreateFrameByType("BACKDROP", "SB_PassiveSection", ui.root, "", 0)
        BlzFrameSetPoint(ui.secPassive, FRAMEPOINT_TOPLEFT,  ui.secActive, FRAMEPOINT_BOTTOMLEFT, 0.0, -GAP_SECTIONS)
        BlzFrameSetPoint(ui.secPassive, FRAMEPOINT_TOPRIGHT, ui.secActive, FRAMEPOINT_BOTTOMRIGHT, 0.0, -GAP_SECTIONS)
        BlzFrameSetSize(ui.secPassive, 0.10, SECTION_H)
        BlzFrameSetTexture(ui.secPassive, TEX_BG_SECTION, 0, true)
        BlzFrameSetLevel(ui.secPassive, 31)

        ui.secPassiveHdr = BlzCreateFrameByType("BACKDROP", "SB_PassiveHdr", ui.secPassive, "", 0)
        BlzFrameSetPoint(ui.secPassiveHdr, FRAMEPOINT_TOPLEFT,  ui.secPassive, FRAMEPOINT_TOPLEFT,  PAD_IN, -PAD_IN)
        BlzFrameSetPoint(ui.secPassiveHdr, FRAMEPOINT_TOPRIGHT, ui.secPassive, FRAMEPOINT_TOPRIGHT, -PAD_IN, -PAD_IN)
        BlzFrameSetSize(ui.secPassiveHdr, 0.10, 0.018)
        BlzFrameSetTexture(ui.secPassiveHdr, TEX_BG_SECTION_HDR, 0, true)
        BlzFrameSetLevel(ui.secPassiveHdr, 32)

        ui.txtPassiveHdr = BlzCreateFrameByType("TEXT", "SB_PassiveHdrText", ui.secPassiveHdr, "", 0)
        BlzFrameSetAllPoints(ui.txtPassiveHdr, ui.secPassiveHdr)
        BlzFrameSetTextAlignment(ui.txtPassiveHdr, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(ui.txtPassiveHdr, "Passive Spells")
        BlzFrameSetLevel(ui.txtPassiveHdr, 33)

        ui.pageBarPassive = BlzCreateFrameByType("BACKDROP", "SB_PassivePageBar", ui.secPassive, "", 0)
        BlzFrameSetPoint(ui.pageBarPassive, FRAMEPOINT_BOTTOMLEFT, ui.secPassive, FRAMEPOINT_BOTTOMLEFT, PAD_IN, PAD_IN)
        BlzFrameSetPoint(ui.pageBarPassive, FRAMEPOINT_BOTTOMRIGHT, ui.secPassive, FRAMEPOINT_BOTTOMRIGHT, -PAD_IN, PAD_IN)
        BlzFrameSetSize(ui.pageBarPassive, 0.10, PAGEBAR_H)
        BlzFrameSetTexture(ui.pageBarPassive, TEX_BG_PAGEBAR, 0, true)
        BlzFrameSetLevel(ui.pageBarPassive, 32)

        ui.btnPassivePrev = BlzCreateFrameByType("BUTTON", "SB_PassivePrev", ui.pageBarPassive, "", 0)
        BlzFrameSetSize(ui.btnPassivePrev, BUTTON_PAGE_W, PAGEBAR_H - 0.004)
        BlzFrameSetPoint(ui.btnPassivePrev, FRAMEPOINT_LEFT, ui.pageBarPassive, FRAMEPOINT_LEFT, PAD_IN, 0.0)
        BlzFrameSetLevel(ui.btnPassivePrev, 33)

        local bgPPrev = BlzCreateFrameByType("BACKDROP", "", ui.btnPassivePrev, "", 0)
        BlzFrameSetAllPoints(bgPPrev, ui.btnPassivePrev)
        BlzFrameSetTexture(bgPPrev, TEX_BG_SECTION_HDR, 0, true)

        local txtPPrev = BlzCreateFrameByType("TEXT", "", ui.btnPassivePrev, "", 0)
        BlzFrameSetAllPoints(txtPPrev, ui.btnPassivePrev)
        BlzFrameSetTextAlignment(txtPPrev, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(txtPPrev, "<")
        BlzFrameSetLevel(txtPPrev, 34)

        ui.btnPassiveNext = BlzCreateFrameByType("BUTTON", "SB_PassiveNext", ui.pageBarPassive, "", 0)
        BlzFrameSetSize(ui.btnPassiveNext, BUTTON_PAGE_W, PAGEBAR_H - 0.004)
        BlzFrameSetPoint(ui.btnPassiveNext, FRAMEPOINT_RIGHT, ui.pageBarPassive, FRAMEPOINT_RIGHT, -PAD_IN, 0.0)
        BlzFrameSetLevel(ui.btnPassiveNext, 33)

        local bgPNext = BlzCreateFrameByType("BACKDROP", "", ui.btnPassiveNext, "", 0)
        BlzFrameSetAllPoints(bgPNext, ui.btnPassiveNext)
        BlzFrameSetTexture(bgPNext, TEX_BG_SECTION_HDR, 0, true)

        ui.txtPassivePage = BlzCreateFrameByType("TEXT", "SB_PassivePageText", ui.pageBarPassive, "", 0)
        BlzFrameSetAllPoints(ui.txtPassivePage, ui.pageBarPassive)
        BlzFrameSetTextAlignment(ui.txtPassivePage, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(ui.txtPassivePage, "1 / 1")
        BlzFrameSetLevel(ui.txtPassivePage, 34)

        --------------------------------------------------
        -- Initial flags
        --------------------------------------------------
        ui.showLocked     = true
        ui.showPages      = true
        ui.pageActive     = 1
        ui.pagePassive    = 1
        ui.maxPageActive  = 1
        ui.maxPagePassive = 1
        ui.tilesActive    = {}
        ui.tilesPassive   = {}
        ui.entriesActive  = {}
        ui.entriesPassive = {}

        --------------------------------------------------
        -- Events: button highlights
        --------------------------------------------------
        local trigLockedEnter = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigLockedEnter, ui.btnToggleLocked, FRAMEEVENT_MOUSE_ENTER)
        TriggerAddAction(trigLockedEnter, function()
            BlzFrameSetVisible(ui.hlToggleLocked, true)
        end)

        local trigLockedLeave = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigLockedLeave, ui.btnToggleLocked, FRAMEEVENT_MOUSE_LEAVE)
        TriggerAddAction(trigLockedLeave, function()
            BlzFrameSetVisible(ui.hlToggleLocked, false)
        end)

        local trigPagesEnter = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigPagesEnter, ui.btnTogglePages, FRAMEEVENT_MOUSE_ENTER)
        TriggerAddAction(trigPagesEnter, function()
            BlzFrameSetVisible(ui.hlTogglePages, true)
        end)

        local trigPagesLeave = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigPagesLeave, ui.btnTogglePages, FRAMEEVENT_MOUSE_LEAVE)
        TriggerAddAction(trigPagesLeave, function()
            BlzFrameSetVisible(ui.hlTogglePages, false)
        end)

        --------------------------------------------------
        -- Events: locked toggle
        --------------------------------------------------
        local trigLocked = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigLocked, ui.btnToggleLocked, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigLocked, function()
            ui.showLocked = not ui.showLocked
            if ui.showLocked then
                BlzFrameSetText(ui.txtToggleLocked, "Show all")
            else
                BlzFrameSetText(ui.txtToggleLocked, "Only unlocked")
            end
            DisplayTextToPlayer(Player(pid), 0, 0, "[Spellbook] showLocked = " .. tostring(ui.showLocked))
            rebuildAll(pid)
        end)

        --------------------------------------------------
        -- Events: page controls toggle
        --------------------------------------------------
        local trigPages = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigPages, ui.btnTogglePages, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigPages, function()
            ui.showPages = not ui.showPages
            if ui.showPages then
                BlzFrameSetText(ui.txtTogglePages, "Pages on")
            else
                BlzFrameSetText(ui.txtTogglePages, "Pages off")
            end
            DisplayTextToPlayer(Player(pid), 0, 0, "[Spellbook] showPages = " .. tostring(ui.showPages))
            rebuildAll(pid)
        end)

        --------------------------------------------------
        -- Events: page buttons
        --------------------------------------------------
        local trigAPrev = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigAPrev, ui.btnActivePrev, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigAPrev, function()
            if ui.pageActive > 1 then
                ui.pageActive = ui.pageActive - 1
            else
                ui.pageActive = ui.maxPageActive
            end
            rebuildAll(pid)
        end)

        local trigANext = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigANext, ui.btnActiveNext, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigANext, function()
            if ui.pageActive < ui.maxPageActive then
                ui.pageActive = ui.pageActive + 1
            else
                ui.pageActive = 1
            end
            rebuildAll(pid)
        end)

        local trigPPrev = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigPPrev, ui.btnPassivePrev, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigPPrev, function()
            if ui.pagePassive > 1 then
                ui.pagePassive = ui.pagePassive - 1
            else
                ui.pagePassive = ui.maxPagePassive
            end
            rebuildAll(pid)
        end)

        local trigPNext = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigPNext, ui.btnPassiveNext, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigPNext, function()
            if ui.pagePassive < ui.maxPagePassive then
                ui.pagePassive = ui.pagePassive + 1
            else
                ui.pagePassive = 1
            end
            rebuildAll(pid)
        end)
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function PlayerMenu_SpellbookModule.ShowInto(pid, contentFrame)
        if not contentFrame then
            return
        end

        local ui = UI[pid]
        if not ui then
            UI[pid] = {}
            ui = UI[pid]
            buildStaticUI(pid, contentFrame)
        else
            ui.root = contentFrame
            if ui.bgMain then
                BlzFrameSetAllPoints(ui.bgMain, ui.root)
            end
        end

        setStaticVisible(ui, true)
        setTilesVisible(ui.tilesActive, true)
        setTilesVisible(ui.tilesPassive, true)
        rebuildAll(pid)
    end

    function PlayerMenu_SpellbookModule.Hide(pid)
        local ui = UI[pid]
        if not ui then
            return
        end
        setTilesVisible(ui.tilesActive, false)
        setTilesVisible(ui.tilesPassive, false)
        setStaticVisible(ui, false)
        hideTooltipFor(pid)
        BlzFrameSetVisible(ui.root, false)
        UI[pid] = nil
    end
end

if Debug and Debug.endFile then Debug.endFile() end
