if Debug and Debug.beginFile then Debug.beginFile("BagSystem.lua") end
--==================================================
-- BagSystem.lua
-- Simple follower bag unit system.
-- • Follows hero smoothly.
-- • Invulnerable, invisible, ignored by all logic.
--==================================================

if not BagSystem then BagSystem = {} end
_G.BagSystem = BagSystem

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local BAG_UNIT_ID  = FourCC("hBAG") -- custom bag unit
    local CHECK_INTERVAL = 0.50
    local MAX_DISTANCE = (GameBalance and GameBalance.BAG and GameBalance.BAG.MAX_DISTANCE) or 400.0
    local FX_ON_SNAP = (GameBalance and GameBalance.BAG and GameBalance.BAG.FX_ON_SNAP)
                        or "Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTarget.mdl"

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local bags = {}   -- pid -> bag unit

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function getHero(pid)
        if _G.PlayerData and PlayerData.Get then
            local pd = PlayerData.Get(pid)
            return pd and pd.hero or nil
        end
        return nil
    end

    --------------------------------------------------
    -- Core
    --------------------------------------------------
    local function ensureBag(pid)
        if bags[pid] and validUnit(bags[pid]) then return bags[pid] end
        local hero = getHero(pid)
        if not validUnit(hero) then return nil end

        local x, y = GetUnitX(hero), GetUnitY(hero)
        local bag = CreateUnit(Player(pid), BAG_UNIT_ID, x, y, 0)
        SetUnitInvulnerable(bag, true)
        ShowUnit(bag, false)
        SetUnitPathing(bag, false)
        UnitRemoveAbility(bag, FourCC("Amov")) -- prevent bag movement command
        bags[pid] = bag
        return bag
    end

    local function followLoop()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            local hero = getHero(pid)
            local bag  = ensureBag(pid)
            if validUnit(hero) and validUnit(bag) then
                local hx, hy = GetUnitX(hero), GetUnitY(hero)
                local bx, by = GetUnitX(bag), GetUnitY(bag)
                local dx, dy = hx - bx, hy - by
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist > MAX_DISTANCE then
                    SetUnitX(bag, hx - 60)
                    SetUnitY(bag, hy - 60)
                    DestroyEffect(AddSpecialEffect(FX_ON_SNAP, hx, hy))
                else
                    SetUnitX(bag, bx + dx * 0.25)
                    SetUnitY(bag, by + dy * 0.25)
                end
            end
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function BagSystem.GetBag(pid)
        return ensureBag(pid)
    end

    function BagSystem.IgnoreInCombat(u)
        return validUnit(u) and GetUnitTypeId(u) == BAG_UNIT_ID
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        TimerStart(CreateTimer(), CHECK_INTERVAL, true, followLoop)
        print("[BagSystem] ready (bags follow heroes, ignored in combat)")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("BagSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
