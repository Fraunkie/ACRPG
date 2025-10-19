if Debug and Debug.beginFile then Debug.beginFile("BootFlow_StartHandler.lua") end
--==================================================
-- BootFlow_StartHandler.lua
-- First-run character creation, then mark Yemma intro pending.
-- • Uses total-initialization OnInit.final
-- • ASCII only
--==================================================

if not BootFlow then BootFlow = {} end
_G.BootFlow = BootFlow

do
    local GB   = GameBalance or {}
    local IDS  = (GB.TELEPORT_NODE_IDS) or {}

    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function PD(pid)
        if not PLAYER_DATA then PLAYER_DATA = {} end
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end

    local function ensureHero(pid)
        local pd = PD(pid)
        if ValidUnit(pd.hero) then return pd.hero end
        if _G.PlayerHero and ValidUnit(PlayerHero[pid]) then
            pd.hero = PlayerHero[pid]
            return pd.hero
        end
        return nil
    end

    local function startCharacterCreation(pid)
        -- prefer adapter if present
        if _G.CharacterCreation_Adapter and CharacterCreation_Adapter.Start then
            pcall(CharacterCreation_Adapter.Start, pid, function()
                PD(pid).yemmaIntroPending = true
            end)
            return
        end
        -- fallback to classic CC
        if _G.CharacterCreation and CharacterCreation.Start then
            pcall(CharacterCreation.Start, pid, function()
                PD(pid).yemmaIntroPending = true
            end)
            return
        end
        -- if no creator available, just mark pending
        PD(pid).yemmaIntroPending = true
    end

    function BootFlow.BeginForPlayer(pid)
        -- ensure hero or start creation
        local h = ensureHero(pid)
        if not h then
            startCharacterCreation(pid)
        else
            local pd = PD(pid)
            if not pd.yemmaIntroSeen then
                pd.yemmaIntroPending = true
            end
        end

        -- make sure Yemma node is known
        if _G.TeleportSystem and TeleportSystem.Unlock then
            TeleportSystem.Unlock(pid, IDS.YEMMA or "YEMMA")
        end
    end

    OnInit.final(function()
        -- bootstrap all human player slots
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerSlotState(Player(pid)) == PLAYER_SLOT_STATE_PLAYING then
                BootFlow.BeginForPlayer(pid)
            end
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("BootFlow_StartHandler")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
