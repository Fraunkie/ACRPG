if Debug and Debug.beginFile then Debug.beginFile("OnHitPassives.lua") end
--==================================================
-- OnHitPassives.lua
-- • Called from CombatEventsBridge.onDamageCurrent(...)
-- • Melee-only (we only run on real melee hits)
-- • Unlock check is TABLE-DRIVEN (Spellbook-style), NOT "unit has ability"
-- • If unlocked: deal extra MAGIC damage so blue text shows
-- • Safe for WC3 editor (no percent symbols, no string.format)
--==================================================

OnHitPassives = OnHitPassives or {}
_G.OnHitPassives = OnHitPassives

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    -- Turn on while testing
    local DEBUG = true

    -- This is your first on-hit passive
    -- A003 = your dummy/icon passive
    local PASSIVES = {
        {
            abil    = FourCC("A003"),
            id      = "POWER_PROC",
            scale   = 0.20,    -- bonus = powerLevel * 0.20
            magic   = true,    -- apply as magic/energy
        },

        -- Phantom Echo passive
        {
            abil    = FourCC("A0PE"),  -- Phantom Echo Ability ID 
            id      = "PHANTOM_ECHO",
        }
    }

    --------------------------------------------------
    -- Small helpers
    --------------------------------------------------
    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function heroOf(pid)
        if PLAYER_DATA and PLAYER_DATA[pid] and validUnit(PLAYER_DATA[pid].hero) then
            return PLAYER_DATA[pid].hero
        end
        if _G.PlayerHero and validUnit(PlayerHero[pid]) then
            return PlayerHero[pid]
        end
        return nil
    end

    local function getPowerLevel(pid)
        if PLAYER_DATA and PLAYER_DATA[pid] and type(PLAYER_DATA[pid].powerLevel) == "number" then
            return PLAYER_DATA[pid].powerLevel
        end
        return 0
    end

    --------------------------------------------------
    -- Spellbook-style unlock check
    -- This is the important part: we look into GameBalance
    -- the same way the Spellbook module does.
    --------------------------------------------------
    local function isPassiveUnlockedFor(pid, abilId)
        -- Dev bypass
      --  if _G.DevMode and DevMode.IsOn and DevMode.IsOn(pid) then
      --      return true
       -- end

        local GB = rawget(_G, "GameBalance")
        if not GB then
            return false
        end

        -- 1) find hero unit
        local hero = heroOf(pid)
        if not validUnit(hero) then
            return false
        end
        local unitTypeId = GetUnitTypeId(hero)

        -- 2) get the per-unit unlock list (this matches PlayerMenu_SpellbookModule)
        local perUnit = (GB.GetSpellUnlocksByUnit and GB.GetSpellUnlocksByUnit()) or GB.SPELL_UNLOCKS_BY_UNIT or {}
        local list    = perUnit[unitTypeId]
        if not list then
            return false
        end

        -- 3) walk entries, find the one with this abil
        for i = 1, #list do
            local entry = list[i]
            if entry and entry.abil then
                local entryId = entry.abil
                if type(entryId) == "string" then
                    entryId = FourCC(entryId)
                end
                if entryId == abilId then
                    -- run same style of requirements the spellbook does
                    local need = entry.need or {}

                    -- soul-level
                    if need.sl_min then
                        local sl = 0
                        if _G.SoulEnergyLogic and SoulEnergyLogic.GetLevel then
                            local ok, v = pcall(SoulEnergyLogic.GetLevel, pid)
                            if ok and type(v) == "number" then
                                sl = v
                            end
                        elseif PLAYER_DATA and PLAYER_DATA[pid] and PLAYER_DATA[pid].soulLevel then
                            sl = PLAYER_DATA[pid].soulLevel
                        end
                        if sl < need.sl_min then
                            return false
                        end
                    end

                    -- power-level
                    if need.pl_min then
                        local pl = getPowerLevel(pid)
                        if pl < need.pl_min then
                            return false
                        end
                    end

                    -- (role / family could go here later if you want)
                    return true
                end
            end
        end

        return false
    end

    --------------------------------------------------
    -- Actual application of bonus damage
    --------------------------------------------------
    local function applyBonusMagic(src, tgt, amount)
        if amount <= 0 then
            return
        end

        -- try DamageEngine first
        if _G.DamageEngine and DamageEngine.applySpellDamage then
            local dealt = DamageEngine.applySpellDamage(src, tgt, amount, DAMAGE_TYPE_MAGIC)
            if DamageEngine.showArcingDamageText then
                DamageEngine.showArcingDamageText(src, tgt, dealt, DAMAGE_TYPE_MAGIC)
            end
        else
            -- fallback native
            UnitDamageTarget(src, tgt, amount, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_NONE)
            if _G.DamageEngine and DamageEngine.showArcingDamageText then
                DamageEngine.showArcingDamageText(src, tgt, amount, DAMAGE_TYPE_MAGIC)
            end
        end
    end

    --------------------------------------------------
    -- Public entry point
    -- Called from CombatEventsBridge:
    --   OnHitPassives.Run(pid, src, tgt, amt, true)
    --------------------------------------------------
    function OnHitPassives.Run(pid, src, tgt, baseDamage, isMelee)
        if not isMelee then
            return
        end
        if not validUnit(src) or not validUnit(tgt) then
            return
        end
        if not pid then
            return
        end

        if DEBUG then
            DisplayTextToPlayer(Player(pid), 0, 0, "[OnHitPassives] run")
        end

        -- walk configured passives
        for i = 1, #PASSIVES do
            local p = PASSIVES[i]
            local abilId = p.abil

            if isPassiveUnlockedFor(pid, abilId) then
                -- compute bonus
                local power = getPowerLevel(pid)
                local bonus = power * (p.scale or 0)
                -- cheap round to int
                bonus = math.floor(bonus + 0.5)
                if bonus < 1 then
                    bonus = 1
                end

                if DEBUG then
                    DisplayTextToPlayer(
                        Player(pid), 0, 0,
                        "[OnHitPassives] "..p.id.." proc for "..tostring(bonus).." (power "..tostring(power)..")"
                    )
                end

                -- apply as magic so we get BLUE tag
                applyBonusMagic(src, tgt, bonus)

                -- Check if Phantom Echo is unlocked and apply
                if p.id == "PHANTOM_ECHO" then
                    if isPassiveUnlockedFor(pid, FourCC("A0PE")) then
                        -- Apply Phantom Echo buff
                        Spell_PassivePhantomEcho.AddToUnit(src)
                    end
                end
            else
                if DEBUG then
                    DisplayTextToPlayer(
                        Player(pid), 0, 0,
                        "[OnHitPassives] passive not unlocked (spellbook logic)"
                    )
                end
            end
        end
    end
end

if Debug and Debug.endFile then Debug.endFile() end
