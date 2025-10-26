if Debug and Debug.beginFile then Debug.beginFile("CompanionAbilities.lua") end
--==================================================
-- CompanionAbilities.lua (v1.0)
-- Triggered companion abilities shared by all templates.
-- • Auto-heal for healer companions using template.abilityDefs.heal
-- • Reads owner INT and spell power safely
-- • Cooldown, range, and visuals handled here
-- • Listens to ProcBus "CompanionSpawned" and "CompanionDespawned"
--==================================================

if not CompanionAbilities then CompanionAbilities = {} end
_G.CompanionAbilities = CompanionAbilities

do
  --------------------------------------------------
  -- Tunables
  --------------------------------------------------
  local TICK             = 0.15     -- how often we evaluate abilities
  local HEAL_THRESHOLD   = 0.70     -- owner hp ratio to trigger heal if not overridden
  local FX_HEAL_TARGET   = "Abilities\\Spells\\Human\\Heal\\HealTarget.mdl"
  local FX_HEAL_CASTER   = "Abilities\\Spells\\Human\\Heal\\HealCaster.mdl"

  --------------------------------------------------
  -- State
  --------------------------------------------------
  -- by pid: { u=unit, owner=unit, template=table, healCD=number }
  local S = {}
  local timerObj = nil

  --------------------------------------------------
  -- Safe stat readers
  --------------------------------------------------
  local function valid(u) return u and GetUnitTypeId(u) ~= 0 end

  local function getOwner(pid)
    local PD = rawget(_G, "PlayerData")
    if PD and PD.GetHero then
      local ok, u = pcall(PD.GetHero, pid)
      if ok and valid(u) then return u end
    end
    return nil
  end

  local function getINT(pid)
    -- Preferred: PlayerMInt mirror used in your project
    local v = (rawget(_G, "PlayerMInt") and PlayerMInt[pid]) or nil
    if type(v) == "number" then return v end
    -- Optional: HeroStatSystem fallback if available
    if _G.HeroStatSystem and HeroStatSystem.GetAll then
      local owner = getOwner(pid)
      if owner then
        local ok, all = pcall(HeroStatSystem.GetAll, owner)
        if ok and all and type(all.int) == "number" then return all.int end
      end
    end
    return 0
  end

  local function getSpellBonusMult(pid)
    local PD = rawget(_G, "PlayerData")
    if PD and PD.GetSpellBonusPct then
      local pct = PD.GetSpellBonusPct(pid) or 0.0
      -- stored as fraction, example zero point five means fifty percent
      return 1.0 + pct
    end
    return 1.0
  end

  local function dist2(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return dx*dx + dy*dy
  end

  local function now()
    if os and os.clock then return os.clock() end
    return 0
  end

  --------------------------------------------------
  -- Heal engine
  --------------------------------------------------
  local function computeHealAmount(pid, def)
    -- def fields: base, coefINT, coefSpell
    local base     = tonumber(def.base or 0) or 0
    local intPart  = (tonumber(def.coefINT or 0) or 0) * getINT(pid)
    local spPart   = (tonumber(def.coefSpell or 0) or 0) * getINT(pid) -- if you want pure spell power value, change here
    local mult     = getSpellBonusMult(pid)
    local amt      = (base + intPart + spPart)
    if mult and mult ~= 1.0 then amt = amt * mult end
    if amt < 0 then amt = 0 end
    return math.floor(amt + 0.5)
  end

  local function tryHeal(pid, rec)
    local owner = rec.owner
    if not valid(owner) then return end
    local u = rec.u
    if not valid(u) then return end

    -- resolve definition
    local t = rec.template or {}
    local defs = t.abilityDefs or {}
    local heal = defs.heal
    if not heal then return end

    -- threshold, cd and range
    local cd     = tonumber(heal.cd or 10.0) or 10.0
    local range  = tonumber(heal.range or 600.0) or 600.0
    local thresh = tonumber(heal.threshold or HEAL_THRESHOLD) or HEAL_THRESHOLD

    -- cooldown gate
    local tnow = now()
    if rec.healCD and tnow < rec.healCD then return end

    -- owner hp check
    local maxhp = BlzGetUnitMaxHP(owner)
    if maxhp <= 0 then return end
    local ratio = GetWidgetLife(owner) / maxhp
    if ratio > thresh then return end

    -- distance gate
    local ux, uy = GetUnitX(u), GetUnitY(u)
    local ox, oy = GetUnitX(owner), GetUnitY(owner)
    if dist2(ux, uy, ox, oy) > (range * range) then return end

    -- compute heal and apply
    local amount = computeHealAmount(pid, heal)
    if amount <= 0 then return end

    -- optional: issue the order for animation parity if catalog provided order id
    local order = t.healAbilityId
    if type(order) == "number" and order > 0 then
      IssueTargetOrderById(u, order, owner)
    end

    local newHp = math.min(maxhp, GetWidgetLife(owner) + amount)
    SetWidgetLife(owner, newHp)

    -- visuals
    if FX_HEAL_TARGET and FX_HEAL_TARGET ~= "" then
      DestroyEffect(AddSpecialEffectTarget(FX_HEAL_TARGET, owner, "origin"))
    end
    if FX_HEAL_CASTER and FX_HEAL_CASTER ~= "" then
      DestroyEffect(AddSpecialEffectTarget(FX_HEAL_CASTER, u, "origin"))
    end

    -- threat adapter for healing listeners
    local PB = rawget(_G, "ProcBus")
    if PB and PB.Emit then
      PB.Emit("OnHealed", { healer = u, target = owner, amount = amount })
    end

    -- cooldown
    rec.healCD = tnow + cd
  end

  --------------------------------------------------
  -- Tick and wiring
  --------------------------------------------------
  local function tick()
    for pid, rec in pairs(S) do
      -- refresh owner in case it changed
      rec.owner = getOwner(pid) or rec.owner
      if rec.owner and valid(rec.u) then
        -- Healers only: role string may be lower or upper depending on template
        local role = (rec.template and rec.template.role) or "HEALER"
        local up   = string.upper(role or "")
        if up == "HEALER" then
          tryHeal(pid, rec)
        end
      end
    end
  end

  local function onSpawn(e)
    if not e then return end
    local pid, u, t = e.pid, e.unit, e.template
    if pid == nil or not valid(u) then return end
    S[pid] = S[pid] or { u=u, owner=getOwner(pid), template=t, healCD=0 }
    S[pid].u = u
    S[pid].template = t
    S[pid].owner = getOwner(pid)
  end

  local function onDespawn(e)
    if not e then return end
    local pid = e.pid
    if pid ~= nil then S[pid] = nil end
  end

  OnInit.final(function()
    timerObj = CreateTimer()
    TimerStart(timerObj, TICK, true, tick)

    local PB = rawget(_G, "ProcBus")
    if PB and PB.On then
      PB.On("CompanionSpawned", onSpawn)
      PB.On("CompanionDespawned", onDespawn)
    end

    if rawget(_G, "InitBroker") and InitBroker.SystemReady then
      InitBroker.SystemReady("CompanionAbilities")
    end
  end)
end

if Debug and Debug.endFile then Debug.endFile() end
