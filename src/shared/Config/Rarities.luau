--[[
	Rarities (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Rarities

	Skill rarity controls how much power each SLOT level adds to a skill's
	damage, healing and shield amounts. (Levels belong to the slot, not the
	skill; see Skills.lua. Every slot has the same level cap.) A rarer skill
	therefore scales better as its slot is levelled, on top of having stronger
	base numbers in Config/Abilities.

	  Order           sort order, low to high
	  PowerPerLevel   fraction added to the skill's effect per slot level above 1

	A skill can override PowerPerLevel with its own LevelBonus field.
	Equipment can reuse these rarities later (Common, Rare, Epic for the
	prototype; Legendary etc. can be added here without touching code).

	Every number is a PLACEHOLDER to be tuned during playtesting.
]]

return {
	Common = {
		Id = "Common",
		DisplayName = "Common",
		Order = 1,
		PowerPerLevel = 0.08,
		Color = { 190, 190, 190 }, -- RGB
	},

	Rare = {
		Id = "Rare",
		DisplayName = "Rare",
		Order = 2,
		PowerPerLevel = 0.10,
		Color = { 70, 140, 255 }, -- RGB
	},

	Epic = {
		Id = "Epic",
		DisplayName = "Epic",
		Order = 3,
		PowerPerLevel = 0.12,
		Color = { 170, 90, 230 }, -- RGB
	},

	Legendary = {
		Id = "Legendary",
		DisplayName = "Legendary",
		Order = 4,
		PowerPerLevel = 0.14,
		Color = { 255, 176, 48 }, -- RGB
	},
}
