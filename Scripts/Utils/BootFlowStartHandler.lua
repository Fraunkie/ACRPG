if Debug and Debug.beginFile then Debug.beginFile("BootFlowStartHandler.lua") end
--==================================================
-- BootFlowStartHandler.lua
-- No auto creation. Listens for hero creation to set intro flags.
-- Also unlocks Yemma teleport once a hero exists.
--==================================================

if not BootFlow then BootFlow = {} end
_G.BootFlow = BootFlow

do
    local GB  = GameBalance or {}
    local IDS = GB.TELEPORT_NODE_IDS or {}

    local function PD(pid)
        PLAYER_DATA = PLAYER_DATA or {}
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end
    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    -- When a hero is created, mark intro pending (if not seen) and unlock Yemma node.
    local function onHeroCreated(e)
        if not e or not e.unit then return end
        local p = GetOwningPlayer(e.unit)
        if not p then return end
        local pid = GetPlayerId(p)
        local pd = PD(pid)

        if not pd.yemmaIntroSeen then
            pd.yemmaIntroPending = true
        end

        if _G.TeleportSystem and TeleportSystem.Unlock then
            TeleportSystem.Unlock(pid, IDS.YEMMA or "YEMMA")
        end
    end

    OnInit.final(function()
        -- Subscribe to CharacterCreation event if available
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnHeroCreated", onHeroCreated)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("BootFlow_StartHandler")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
