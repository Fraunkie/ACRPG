if Debug and Debug.beginFile then Debug.beginFile("LootSystem_Bridge.lua") end
--==================================================
-- LootSystem_Bridge.lua
-- Listens for kill events and asks LootSystem to drop rewards
-- for the threat group that contributed to the kill.
-- • Uses ThreatSystem.GetThreat(hero, dead) to find contributors
-- • Falls back to killer only if no threat found
-- • Ignores bag units automatically through LootSystem
--==================================================

if not LootSystem_Bridge then LootSystem_Bridge = {} end
_G.LootSystem_Bridge = LootSystem_Bridge

do
    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function pidOf(u) local p = GetOwningPlayer(u); return p and GetPlayerId(p) or nil end

    local function getHero(pid)
        if _G.PlayerData and PlayerData.Get then
            local pd = PlayerData.Get(pid)
            if pd and pd.hero and validUnit(pd.hero) then return pd.hero end
        end
        return nil
    end

    -- Build the list of pids who had threat on the dead unit
    local function buildThreatGroup(dead, killerPid)
        local list = {}
        local any = false

        local TS = rawget(_G, "ThreatSystem")
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                local u = getHero(pid)
                if validUnit(u) then
                    local has = 0
                    if TS and TS.GetThreat then
                        local ok, v = pcall(TS.GetThreat, u, dead)
                        if ok and type(v) == "number" then has = v end
                    end
                    if has > 0 then
                        list[#list + 1] = pid
                        any = true
                    end
                end
            end
        end

        -- If nobody had explicit threat, at least include the killer
        if not any and killerPid ~= nil then
            list[#list + 1] = killerPid
        end
        return list
    end

    --------------------------------------------------
    -- Event wiring
    --------------------------------------------------
    local function onKill(e)
        if not e then return end
        local dead   = e.target or e.dead
        local killer = e.source or e.killer
        if not validUnit(dead) then return end

        -- killer may be nil for some lethal sources
        local kpid = validUnit(killer) and pidOf(killer) or nil

        local players = buildThreatGroup(dead, kpid)

        if _G.LootSystem and LootSystem.DropLoot then
            local ok, err = pcall(LootSystem.DropLoot, dead, players)
            if not ok then
                print("[LootBridge] drop error " .. tostring(err))
            end
        else
            print("[LootBridge] LootSystem not available")
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnKill", onKill)
            print("[LootBridge] wired to ProcBus OnKill")
        else
            -- Native fallback if ProcBus is not present
            local t = CreateTrigger()
            for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
                TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
            end
            TriggerAddAction(t, function()
                local e = { target = GetTriggerUnit(), source = GetKillingUnit() }
                onKill(e)
            end)
            print("[LootBridge] wired to native death events")
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("LootSystem_Bridge")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
