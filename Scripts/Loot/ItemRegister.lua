if Debug and Debug.beginFile then Debug.beginFile("items_register.lua") end
--==================================================
-- items_register.lua
-- Registers the three core items from your current ItemDatabase:
--   • Goz's Gloves (I00G)
--   • Mez's Hammer (I00D)
--   • Old Armor    (I004)
--
-- Notes:
-- - Uses RegisterEx (table form) for clarity.
-- - Includes category/slot and the stats we’re using everywhere else.
-- - Safe to run multiple times; entries are replaced idempotently.
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
      -- allowedHeroTypes / required fields can be added later if needed
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
  })
end)

if Debug and Debug.endFile then Debug.endFile() end
