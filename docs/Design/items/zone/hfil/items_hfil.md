📜 1. Item Design Table (for Object Editor / Documentation)

You can expand this table infinitely — just add new rows for new zones or universes.
I used simple text spacing so you can copy it into Notepad or Excel if you want to track items externally.

ID	Name	Tier	Type	Description	Effect / Script Call	Notes / Use case
I001	Spirit Fragment	Common	Material	Shard of a broken soul. Used in forging Soul Cores.	None	Stackable; basic crafting material.
I002	Faded Charm	Common	Consumable	A charm that grants a faint power boost.	+1 to all stats for 60s	Use Timed buff.
I003	Lesser Tome of Power	Common	Consumable	Grants permanent +1 random base stat.	HeroStatSystem.AddPlayerBaseStat(playerId, randomStat, 1)	Permanent growth item.
I004	Wisp Dust	Common	Material	Dust left by wandering souls. Used in alchemy.	None	Stackable.
I005	Condensed Soul	Uncommon	Consumable	Converts into 10 SoulEnergy when used.	SoulEnergy.Add(playerId, 10)	Refillable energy consumable.
I006	Ethereal Band	Uncommon	Equipment	Ring infused with spectral energy. +3 INT, +3 AGI while equipped.	Equip effect or HeroStatSystem.AddPlayerBaseStat	Equip item.
I007	Spiritblade Fragment	Uncommon	Material	Fragment of a weapon; used in forging.	None	Crafting material.
I008	Spectral Essence	Uncommon	Material	Used to upgrade skills.	None	Stackable.
I009	Soul Core (Lesser)	Rare	Artifact	A core of condensed souls; used for tier-ups.	TierSystem.Requirement or SoulEnergy.Add(playerId, 50)	Tier progression item.
I00A	Spirit Mantle	Rare	Equipment	Mantle of spirit cloth. +5 to all stats when equipped.	Equip or HeroStatSystem.AddPlayerBaseStat	Armor.
I00B	Echo Crystal	Rare	Material	Resonates across dimensions; used for fusions.	None	Crafting.
I00C	Orb of the Forgotten	Rare	Consumable	Grants +25 Soul Energy on use.	SoulEnergy.Add(playerId, 25)	High-value consumable.
I00D	Cursed Halo	Elite	Artifact	Twisted halo; grants stat bonus and aura.	Equip, cosmetic aura	Unique drop.
I00E	Guardian’s Sigil	Elite	Quest Item	Symbol of passage; needed for Kami’s Lookout.	Quest key	Zone unlock requirement.