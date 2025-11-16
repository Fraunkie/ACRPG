if Debug and Debug.beginFile then Debug.beginFile("items_register.lua") end
--==================================================
-- items_register.lua
-- Registers the items from your current ItemDatabase:
-- Defines Buffs
--==================================================

OnInit.final(function()
  if not _G.ItemDatabase or not ItemDatabase.RegisterEx then
    print("|cffff5555[items_register]|r ItemDatabase.RegisterEx missing; ensure ItemDatabase.lua loads first.")
    return
  end

  -- Bulk register (replace or create)
  ItemDatabase.BulkRegister({
    [FourCC("I00G")] = {
      name        = "HFIL Shackles",
      description = "Chains that weigh heavy but focus your resolve.",
      iconpath    = "ReplaceableTextures\\CommandButtons\\BTNHFILShackles.blp",
      category    = "HANDS",
      slot        = "Bracers",           -- UI slot that matches your equip board
      stats       = { defense = 2, attackspeed = 0.05 },
    },

    [FourCC("I00H")] = {
      name        = "Companions License",
      description = "A license granting permission to summon companions.",
      iconpath    = "ReplaceableTextures\\CommandButtons\\BTNGozsGloves.blp",
      category    = "MISC",
    },

    [FourCC("I00D")] = {
      name        = "Soul-Scarred Club",
      description = "A crude weapon formed from a tormented soul's remnants",
      iconpath    = "ReplaceableTextures\\CommandButtons\\BTNSoulScarredClub.blp",
      category    = "WEAPON",
      slot        = "Weapon",
      stats       = { attack = 8, physPowerPct = 0.05 },
    },

    [FourCC("I004")] = {
      name        = "Tattered Soul Cloth",
      description = "Fragments of robes worn by punished souls.",
      iconpath    = "ReplaceableTextures\\CommandButtons\\BTNTatteredSoulcloth.blp",
      category    = "CHEST",
      slot        = "Chest",
      stats       = { hp = 120, defense = 6 },
    },

    [FourCC("I00W")] = {
      name = "Goku Ascension Shard (Uncharged)",
      description = "Shard used to change your hero.",
      iconpath = "ReplaceableTextures\\CommandButtons\\BTNTatteredSoulcloth.blp",
      category = "MISC",
    },

    -- New Food Items
    [FourCC("I00F")] = {  -- Food Item: Healing Herb
      name        = "Healing Herb",
      description = "A herb that restores health.",
      iconpath    = "ReplaceableTextures\\CommandButtons\\BTNHealingHerb.blp",
      category    = "FOOD",
      stackable   = true,  -- Mark as stackable
      stats       = { hp = 50 },  -- Healing amount
    },

    [FourCC("I00B")] = {  -- Food Item: Mystic Elixir
      name        = "Mystic Elixir",
      description = "A magical drink that boosts strength temporarily.",
      iconpath    = "ReplaceableTextures\\CommandButtons\\BTNElixir.blp",
      category    = "FOOD",
      stats       = { attack = 10 },  -- Temporary attack boost
    },
  })
end)
--------------------------------------------------
---ItemBuffs
--------------------------------------------------
ItemBuffs = ItemBuffs or {}
-- Buff for Healing Herb
ItemBuffs[FourCC("I00F")] = {
    name = "Healing Herb",
    tooltip = "Heals for !health! of the target's max health.",
    icon = "ReplaceableTextures\\CommandButtons\\BTNHealingHerb.blp",  -- Same as Healing Herb item icon
    type = "Magic",  -- Type of the buff
    duration = 0,  -- Instant heal, no duration
    color = "|cff00ff00",  -- Green color for healing
    effect = "Abilities\\Spells\\NightElf\\Rejuvenation\\RejuvenationTarget.mdl",  -- Rejuvenation effect
    attachPoint = "chest",  -- Attach the effect to the chest
    values = {
        health = function(target, source, level, stacks)
            -- Heal 10 of max HP
            local maxHealth = math.max(1, BlzGetUnitMaxHP(target))
            return maxHealth * 0.1  -- 10 of max HP
        end,
        duration = 0  -- No duration for instant heal
    },
    onApply = function(target, source, values, level, stacks)
        -- Apply the heal
        local healAmount = values.health  -- This is 10 of max HP
        local currentHealth = math.max(0, R2I(GetWidgetLife(target)))  -- Current HP
        SetWidgetLife(target, currentHealth + healAmount)  -- Heal the unit

        -- Display message to the player who owns the target unit
        DisplayTextToPlayer(GetOwningPlayer(target), 0, 0, "Healed " .. tostring(healAmount) .. " HP")
    end
}
if Debug and Debug.endFile then Debug.endFile() end
