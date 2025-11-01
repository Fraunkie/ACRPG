if Debug and Debug.beginFile then Debug.beginFile("AscensionGate.lua") end
--==================================================
-- AscensionGate.lua
-- Detects nearby gates and starts ascension or challenges.
--==================================================

if not AscensionGate then AscensionGate = {} end
_G.AscensionGate = AscensionGate

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local INTERACT_RADIUS = 500.0
    local GATE_UNIT_TYPES = {
        [FourCC("hGAT")] = true,
        [FourCC("nGAT")] = true,
    }
    local ASK_BEFORE_CHALLENGE = true
    local SILENT_UNLESS_READY = true

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[Gate] " .. tostring(s)) end
    end
    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end

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
    -- Core logic
    --------------------------------------------------
    local function handleAscend(pid, tier)
        local hero = getHero(pid)
        if not validUnit(hero) then
            if not SILENT_UNLESS_READY then dprint("no hero") end
            return
        end

        local gate = findNearestGate(hero)
        if not gate then
            if not SILENT_UNLESS_READY then dprint("no gate nearby") end
            return
        end

        if not _G.AscensionSystem or not AscensionSystem.CanAscendNow then
            dprint("AscensionSystem missing")
            return
        end

        local can, reason = AscensionSystem.CanAscendNow(pid, tier)
        if not can then
            if not SILENT_UNLESS_READY then
                dprint("cannot ascend reason " .. tostring(reason))
            end
            return
        end

        -- Qualified: get flow from GameBalance if available
        local famKey = (PLAYER_DATA and PLAYER_DATA[pid] and PLAYER_DATA[pid].family) or "GENERIC"
        local GB = rawget(_G, "GameBalance")
        local flow = (GB and GB.GetGateFlow) and GB.GetGateFlow(famKey, tier or 1) or { mode = "immediate" }
        local mode = flow.mode or "immediate"

        if mode == "immediate" then
            AscensionSystem.TryAscend(pid, tier)
            dprint("ascension complete immediate")
            return
        end

        if mode == "challenge" then
            if ASK_BEFORE_CHALLENGE then
                PD(pid).pendingChallenge = {
                    tier = tier,
                    famKey = famKey,
                    gate = gate,
                    challenge_id = flow.challenge_id or ("GENERIC_TIER_" .. tostring(tier or 1))
                }
                dprint("challenge prepared")
                return
            else
                local id = flow.challenge_id or ("GENERIC_TIER_" .. tostring(tier or 1))
                if _G.AscensionChallenge and AscensionChallenge.Begin then
                    AscensionChallenge.Begin(pid, {
                        tier = tier,
                        familyKey = famKey,
                        gate = gate,
                        challenge_id = id
                    })
                end
                dprint("challenge started")
            end
        end
    end

    --------------------------------------------------
    -- Chat commands
    --------------------------------------------------
    if OnInit and OnInit.final then
        OnInit.final(function()
            local t = CreateTrigger()
            for i = 0, bj_MAX_PLAYERS - 1 do
                TriggerRegisterPlayerChatEvent(t, Player(i), "-ascend", false)
                TriggerRegisterPlayerChatEvent(t, Player(i), "-startchallenge", false)
            end
            TriggerAddAction(t, function()
                local p = GetTriggerPlayer()
                local pid = GetPlayerId(p)
                local msg = GetEventPlayerChatString()
                if string.sub(msg, 1, 7) == "-ascend" then
                    local n = tonumber(string.sub(msg, 9)) or nil
                    handleAscend(pid, n)
                elseif msg == "-startchallenge" then
                    local pend = PD(pid).pendingChallenge
                    if not pend then return end
                    PD(pid).pendingChallenge = nil
                    if _G.AscensionChallenge and AscensionChallenge.Begin then
                        AscensionChallenge.Begin(pid, {
                            tier = pend.tier,
                            familyKey = pend.famKey,
                            gate = pend.gate,
                            challenge_id = pend.challenge_id
                        })
                        dprint("challenge started manually")
                    end
                end
            end)

            -- listen for success event to auto-ascend
            local PB = rawget(_G, "ProcBus")
            if PB and PB.On then
                PB.On("OnAscensionChallengeSuccess", function(e)
                    if not e or e.pid == nil then return end
                    local pid = e.pid
                    local tier = tonumber(e.tier or 1)
                    AscensionSystem.TryAscend(pid, tier)
                end)
            end
            dprint("ready")
        end)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
