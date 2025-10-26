if Debug and Debug.beginFile then Debug.beginFile("CompanionUnitTuning.lua") end
--==================================================
-- CompanionUnitTuning.lua (v1.0)
-- Applies template.unitstats to newly spawned companions.
-- • Listens to ProcBus "CompanionSpawned"
-- • Supported fields under data.unitstats:
--     maxhp = { base = N, coefSTR = A, coefAGI = B, coefINT = C }
--     damage = { base = N, coefSTR = A, coefAGI = B, coefINT = C }
-- • Uses PlayerMStr, PlayerMAgi, PlayerMInt mirrors when available
-- • Safe fallbacks if mirrors or natives are missing
--==================================================

if not CompanionUnitTuning then CompanionUnitTuning = {} end
_G.CompanionUnitTuning = CompanionUnitTuning

do
  --------------------------------------------------
  -- Safe readers
  --------------------------------------------------
  local function valid(u) return u and GetUnitTypeId(u) ~= 0 end

  local function statOrZero(tbl, key)
    local v = tbl and tbl[key]
    return (type(v) == "number") and v or 0
  end

  local function getOwnerStats(pid)
    -- Pull lightweight mirrors first
    local STR = (rawget(_G, "PlayerMStr") and PlayerMStr[pid]) or 0
    local AGI = (rawget(_G, "PlayerMAgi") and PlayerMAgi[pid]) or 0
    local INT = (rawget(_G, "PlayerMInt") and PlayerMInt[pid]) or 0

    -- Optional: HeroStatSystem fallback if mirrors are zero
    if _G.HeroStatSystem and HeroStatSystem.GetAll then
      local PD = rawget(_G, "PlayerData")
      local owner = PD and PD.GetHero and PD.GetHero(pid) or nil
      if owner and valid(owner) then
        local ok, all = pcall(HeroStatSystem.GetAll, owner)
        if ok and all then
          STR = (STR ~= 0) and STR or (all.str or STR)
          AGI = (AGI ~= 0) and AGI or (all.agi or AGI)
          INT = (INT ~= 0) and INT or (all.int or INT)
        end
      end
    end
    return STR or 0, AGI or 0, INT or 0
  end

  --------------------------------------------------
  -- Application
  --------------------------------------------------
  local function applyStats(pid, u, template)
    if not valid(u) or type(template) ~= "table" then return end
    local U = template.unitstats or {}
    if next(U) == nil then return end

    local STR, AGI, INT = getOwnerStats(pid)

    -- Max HP
    if U.maxhp then
      local base = statOrZero(U.maxhp, "base")
      local hp = base
      hp = hp + statOrZero(U.maxhp, "coefSTR") * STR
      hp = hp + statOrZero(U.maxhp, "coefAGI") * AGI
      hp = hp + statOrZero(U.maxhp, "coefINT") * INT
      hp = math.max(1, math.floor(hp + 0.5))
      if BlzSetUnitMaxHP then
        BlzSetUnitMaxHP(u, hp)
        if GetWidgetLife(u) > hp then SetWidgetLife(u, hp) end
      end
    end

    -- Base damage (index 0)
    if U.damage then
      local base = statOrZero(U.damage, "base")
      local dmg = base
      dmg = dmg + statOrZero(U.damage, "coefSTR") * STR
      dmg = dmg + statOrZero(U.damage, "coefAGI") * AGI
      dmg = dmg + statOrZero(U.damage, "coefINT") * INT
      dmg = math.max(0, math.floor(dmg + 0.5))
      if BlzSetUnitBaseDamage then
        BlzSetUnitBaseDamage(u, dmg, 0)
      end
    end

    -- Optional future: armor, movespeed, attack speed, resistances
    -- You can extend with additional fields as needed.
  end

  --------------------------------------------------
  -- Wiring
  --------------------------------------------------
  local function onSpawn(e)
    if not e then return end
    local pid, u, t = e.pid, e.unit, e.template
    if pid == nil or not valid(u) then return end
    applyStats(pid, u, t or {})
  end

  OnInit.final(function()
    local PB = rawget(_G, "ProcBus")
    if PB and PB.On then
      PB.On("CompanionSpawned", onSpawn)
    end
    if rawget(_G, "InitBroker") and InitBroker.SystemReady then
      InitBroker.SystemReady("CompanionUnitTuning")
    end
  end)
end

if Debug and Debug.endFile then Debug.endFile() end
