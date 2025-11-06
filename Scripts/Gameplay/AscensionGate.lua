
if Debug and Debug.beginFile then Debug.beginFile("AscensionGate.lua") end
--==================================================
-- AscensionGate.lua  (locked to charged shard)
-- Shows buttons only if player has charged shard
--==================================================

if not AscensionGate then AscensionGate = {} end
_G.AscensionGate = AscensionGate

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local INTERACT_RADIUS = 500.0
    local GATE_UNIT_TYPES = {
        [FourCC("h00N")] = true,
        [FourCC("nGAT")] = true,
    }
    local ASK_BEFORE_CHALLENGE = true
    local SILENT_UNLESS_READY = true

    local BUTTON_DEBOUNCE_TIME = 1.0 -- 1 second debounce time
    local lastButtonClickTime = {} -- to track button click time

    --------------------------------------------------
    -- Debug helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[AscensionGate] " .. tostring(s)) end
    end

    local function logToConsole(pid, msg)
        DisplayTextToPlayer(Player(pid), 0, 0, "[AscensionGate Debug] " .. tostring(msg))
    end

    --------------------------------------------------
    -- Helper functions
    --------------------------------------------------
    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function PD(pid)
        if not PLAYER_DATA then PLAYER_DATA = {} end
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end

    local function getHero(pid)
        local pd = PD(pid)
        if validUnit(pd.hero) then return pd.hero end
        if rawget(_G, "PlayerHero") and validUnit(PlayerHero[pid]) then return PlayerHero[pid] end
        return nil
    end

    --------------------------------------------------
    -- Button Creation
    --------------------------------------------------
    local function createButtons(pid)
        -- Check the debounce time to prevent multiple clicks
        if lastButtonClickTime[pid] and os.clock() - lastButtonClickTime[pid] < BUTTON_DEBOUNCE_TIME then
            return
        end
        lastButtonClickTime[pid] = os.clock()

        -- Start Challenge button
        local buttonStart = BlzCreateSimpleFrame("BUTTON", 0, 0)
        BlzFrameSetText(buttonStart, "Start Challenge")
        BlzFrameSetSize(buttonStart, 0.2, 0.05)
        BlzFrameSetPoint(buttonStart, FRAMEPOINT_CENTER, BlzGetFrameByName("ConsoleUIBackdrop", 0), FRAMEPOINT_TOP, 0, -0.1)
        BlzFrameSetScript(buttonStart, FRAMEEVENT_MOUSE_BUTTON_DOWN, function()
            logToConsole(pid, "Start Challenge button clicked")
            -- You can add challenge starting logic here
        end)

        -- Exit button
        local buttonExit = BlzCreateSimpleFrame("BUTTON", 0, 0)
        BlzFrameSetText(buttonExit, "Exit")
        BlzFrameSetSize(buttonExit, 0.2, 0.05)
        BlzFrameSetPoint(buttonExit, FRAMEPOINT_CENTER, BlzGetFrameByName("ConsoleUIBackdrop", 0), FRAMEPOINT_TOP, 0, -0.2)
        BlzFrameSetScript(buttonExit, FRAMEEVENT_MOUSE_BUTTON_DOWN, function()
            logToConsole(pid, "Exit button clicked")
            -- You can add exit logic here
        end)
    end

    --------------------------------------------------
    -- Gate proximity detection
    --------------------------------------------------
    local function findNearestGate(u)
        if not validUnit(u) then return nil end
        local ux, uy = GetUnitX(u), GetUnitY(u)
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, ux, uy, INTERACT_RADIUS, nil)
        local best, bestD2 = nil, math.huge
        while true do
            local nu = FirstOfGroup(g)
            if not nu then break end
            GroupRemoveUnit(g, nu)
            if validUnit(nu) and GATE_UNIT_TYPES[GetUnitTypeId(nu)] then
                local dx = GetUnitX(nu) - ux
                local dy = GetUnitY(nu) - uy
                local d2 = dx * dx + dy * dy
                if d2 < bestD2 then
                    best, bestD2 = nu, d2
                end
            end
        end
        DestroyGroup(g)
        return best
    end

    --------------------------------------------------
    -- Ascension button flow (check for charged shard)
    --------------------------------------------------
    local function handleAscension(pid)
        local hero = getHero(pid)
        if not validUnit(hero) then
            if not SILENT_UNLESS_READY then dprint("no hero") end
            return
        end

        -- Check if the player has the charged shard in custom inventory
        if not _G.ShardChargeSystem or not ShardChargeSystem.HasChargedShard(pid) then
            dprint("player doesn't have a charged shard in inventory")
            return
        end

        local gate = findNearestGate(hero)
        if not gate then
            if not SILENT_UNLESS_READY then dprint("no gate nearby") end
            return
        end

        createButtons(pid)  -- Create the buttons once near the gate

        dprint("Ascension Gate: Player " .. tostring(pid) .. " near gate, buttons shown")
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        -- Test: replace with dynamic PID tracking in real case
        local pid = 0  -- Temporary for testing
        handleAscension(pid)
        dprint("Ascension Gate ready")
    end)

end

if Debug and Debug.endFile then Debug.endFile() end
