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
--------------------------------------------------
---HEAD ARMOR
--------------------------------------------------

--------------------------------------------------
---CHEST ARMOR
--------------------------------------------------
    [FourCC("I004")] = {
      name                = "Tattered Soul Cloth",
      description         = "Fragments of robes worn by punished souls.",
      iconpath            = "ReplaceableTextures\\CommandButtons\\BTNTatteredSoulcloth.blp",
      category            = "CHEST",
      slot                = "Chest",
      stats               = { hp = 200, },
    },
    [FourCC("I011")] = {
      name                = "Lost Soul Plate",
      description         = "Heavy armor forged from lost souls’ sorrow.",
      iconpath            = "ReplaceableTextures\\CommandButtons\\BTNLostSoulPlate.blp",
      category            = "CHEST",
      slot                = "Chest",
      stats               = { hp = 200, },
    },
--------------------------------------------------
---WEAPONS
--------------------------------------------------
    [FourCC("I00D")] = {
      name                = "Soul-Scarred Club",
      description         = "A crude weapon formed from a tormented soul's remnants.",
      iconpath            = "ReplaceableTextures\\CommandButtons\\BTNSoulScarredClub.blp",
      category            = "WEAPON",
      slot                = "Weapon",
      stats               = { attack = 9, },
    },
    [FourCC("I00P")] = {
      name                = "HFIL Pitchfork",
      description         = "Used by lazy demons to herd the newly damned.",
      iconpath            = "ReplaceableTextures\\CommandButtons\\BTNHFILPitchfork.blp",
      required            = { powerLevel= 0, soulEnergy= 5 },
      category            = "WEAPON",
      slot                = "Weapon",
      stats               = { attack = 25, agi = 20, },
      
    },
    [FourCC("I010")] = {
      name                = "Ashen Rod",
      description         = "Emits faint embers; favored by lesser sorcerers.",
      iconpath            = "ReplaceableTextures\\CommandButtons\\BTNAshenRod.blp",
      category            = "WEAPON",
      slot                = "Weapon",
      required            = { powerLevel= 0, soulEnergy= 5 },
      stats               = { attack = 25, int = 20, },
    },
--------------------------------------------------
---OFF-HAND
--------------------------------------------------
    [FourCC("I00X")] = {
      name                = "Paperweight of Yemma",
      description         = "A desk weight from Yemma’s bureau, now oddly powerful",
      iconpath            = "ReplaceableTextures\\CommandButtons\\BTNPaperweightofYemma.blp",
      required            = { powerLevel= 0, soulEnergy= 6 },
      category            = "SHIELD",
      slot                = "Shield",
      stats               = { int = 50, agi = 20, str = 20, },
    },
--------------------------------------------------
---BRACERS/HANDS
--------------------------------------------------
    [FourCC("I00G")] = {
      name                = "HFIL Shackles",
      description         = "Chains that weigh heavy but focus your resolve.",
      iconpath            = "ReplaceableTextures\\CommandButtons\\BTNHFILShackles.blp",
      category            = "HANDS",
      slot                = "Bracers",           -- UI slot that matches your equip board
      stats               = { defense = 2, attackspeed = 0.05 },
    },
--------------------------------------------------
---LEGS ARMOR
--------------------------------------------------
    [FourCC("I00I")] = {
      name                = "Charred Greaves",
      description         = "Burnt, yet strangely resilient leg armor.",
      iconpath            = "ReplaceableTextures\\CommandButtons\\BTNCharredGreaves.blp",
      required            = { powerLevel= 0, soulEnergy= 5 },
      category            = "LEGS",
      slot                = "Legs",           -- UI slot that matches your equip board
      stats               = { defense = 10},
    },
--------------------------------------------------
---CLOAK/CAPE 
--------------------------------------------------
--------------------------------------------------
---AMULET/NECKLACE 
--------------------------------------------------
    [FourCC("I005")] = {
      name                = "Ash Pendant",
      description         = "The ashes of the damned sealed in glass.",
      iconpath            = "ReplaceableTextures\\CommandButtons\\BTNCursedBand.blp",
      required            = { powerLevel= 0, soulEnergy= 10 },
      category            = "NECKLACE",
      slot                = "Necklace",           -- UI slot that matches your equip board
      stats               = { int = 100},
    },
--------------------------------------------------
---ACCESSORY 
--------------------------------------------------
    [FourCC("I00J")] = {
      name                = "Burning Halo",
      description         = "A faint halo that glows with residual sin.",
      iconpath            = "ReplaceableTextures\\CommandButtons\\BTNBurningHalo.blp",
      required            = { powerLevel= 0, soulEnergy= 5 },
      category            = "ACCESSORY",
      slot                = "Accessory",           -- UI slot that matches your equip board
      stats               = { energyResist = 0.05},
    },
    [FourCC("I00J")] = {
      name                = "Cursed Band",
      description         = "A ring that hums with corrupted spirit energy.",
      iconpath            = "ReplaceableTextures\\CommandButtons\\BTNCursedBand.blp",
      required            = { powerLevel= 0, soulEnergy= 5 },
      category            = "ACCESSORY",
      slot                = "Accessory",           -- UI slot that matches your equip board
      stats               = { energyResist = 0.05},
    },
--------------------------------------------------
---RINGS 
--------------------------------------------------
--------------------------------------------------
---BOOTS
--------------------------------------------------
    [FourCC("I00E")] = {
      name                = "Burnt Sandals",
      description         = "Scorched footwear that oddly still function.",
      iconpath            = "ReplaceableTextures\\CommandButtons\\BTNBurntSandals.blp",
      required            = { powerLevel= 0, soulEnergy= 5 },
      category            = "LEGS",
      slot                = "Legs",           -- UI slot that matches your equip board
      stats               = { defense = 10},
    },
--------------------------------------------------
---MISC
--------------------------------------------------

    [FourCC("I00H")] = {
      name        = "Companions License",
      description = "A license granting permission to summon companions.",
      iconpath    = "ReplaceableTextures\\CommandButtons\\BTNCompanionLicense.blp",
      category    = "MISC",
    },

--------------------------------------------------
---ASCENSION SHARDS 
--------------------------------------------------

    [FourCC("I00W")] = {
      name = "Goku Ascension Shard (Uncharged)",
      description = "Shard used to change your hero.",
      iconpath = "ReplaceableTextures\\CommandButtons\\BTNOrangeAscensionShard.blp",
      category = "MISC",
    },
    [FourCC("I00C")] = {
      name = "Agumon Ascension Shard (Uncharged)",
      description = "Shard used to change your hero.",
      iconpath = "ReplaceableTextures\\CommandButtons\\BTNOrangeAscensionShard.blp",
      category = "MISC",
    },
    [FourCC("I00O")] = {
      name = "Gabumon Ascension Shard (Uncharged)",
      description = "Shard used to change your hero.",
      iconpath = "ReplaceableTextures\\CommandButtons\\BTNOrangeAscensionShard.blp",
      category = "MISC",
    },
    [FourCC("I00B")] = {
      name = "Charmander Ascension Shard (Uncharged)",
      description = "Shard used to change your hero.",
      iconpath = "ReplaceableTextures\\CommandButtons\\BTNOrangeAscensionShard.blp",
      category = "MISC",
    },
    [FourCC("I014")] = {
      name = "Naruto Ascension Shard (Uncharged)",
      description = "Shard used to change your hero.",
      iconpath = "ReplaceableTextures\\CommandButtons\\BTNOrangeAscensionShard.blp",
      category = "MISC",
    },
    [FourCC("I015")] = {
      name = "Piccolo Ascension Shard (Uncharged)",
      description = "Shard used to change your hero.",
      iconpath = "ReplaceableTextures\\CommandButtons\\BTNOrangeAscensionShard.blp",
      category = "MISC",
    },
    [FourCC("I006")] = {
      name = "Sakura Ascension Shard (Uncharged)",
      description = "Shard used to change your hero.",
      iconpath = "ReplaceableTextures\\CommandButtons\\BTNOrangeAscensionShard.blp",
      category = "MISC",
    },
    [FourCC("I007")] = {
      name = "Squirtle Ascension Shard (Uncharged)",
      description = "Shard used to change your hero.",
      iconpath = "ReplaceableTextures\\CommandButtons\\BTNOrangeAscensionShard.blp",
      category = "MISC",
    },
    [FourCC("I016")] = {
      name = "Vegeta Ascension Shard (Uncharged)",
      description = "Shard used to change your hero.",
      iconpath = "ReplaceableTextures\\CommandButtons\\BTNOrangeAscensionShard.blp",
      category = "MISC",
    },
    
--------------------------------------------------
---FOOD/POTS
--------------------------------------------------
    -- New Food Items
    [FourCC("I00F")] = {  -- Food Item: Healing Herb
      name        = "Healing Herb",
      description = "A herb that restores health.",
      iconpath    = "ReplaceableTextures\\CommandButtons\\BTNHealingHerbItem.blp",
      category    = "FOOD",
      stackable   = true,  -- Mark as stackable
      stackcount  = 0,
      stats       = { hp = 50 },  -- Healing amount
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
    icon = "ReplaceableTextures\\CommandButtons\\BTNHealingHerbItem.blp",  -- Same as Healing Herb item icon
    type = "Magic", 
    color = "|cff00ff00",  -- Green color for healing
    effect = "Abilities\\Spells\\NightElf\\Rejuvenation\\RejuvenationTarget.mdl",  -- Rejuvenation effect
    attachPoint = "chest",  -- Attach the effect to the chest
    values = {
        health = function(target, source, level, stacks)
            -- Heal 10 of max HP
            local maxHealth = math.max(1, BlzGetUnitMaxHP(target))
            return maxHealth * 0.1  -- 10 of max HP
        end,
        duration = 5,
    },
    onPeriodic = function(target, source, values, level, stacks)
        local healPerSecond =  GetUnitState(target, UNIT_STATE_LIFE) + ALICE_Config.MIN_INTERVAL*values.health/values.duration
        SetUnitState(target, UNIT_STATE_LIFE, GetUnitState(target, UNIT_STATE_LIFE) + ALICE_Config.MIN_INTERVAL*values.health/values.duration)
      --  NeatMessageToPlayerTimed(GetOwningPlayer(target), 1, "Healed " .. tostring(healPerSecond) .. " HP")
    end
}
if Debug and Debug.endFile then Debug.endFile() end
