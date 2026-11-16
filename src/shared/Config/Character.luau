--[[
	Character (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > Character

	Options for the character creator. Looks are INDEXES into these lists (the server only stores numbers),
	so a hacked client cannot save a colour that is not on the list.
	Every number and colour is a first guess.
]]

return {
	Name = { Min = 3, Max = 14 },
	RenameCost = 100, -- Sunstones; the first name (at creation) is free
	-- A small local blocklist on top of Roblox's own text filter (the server also runs TextService). Lower case, letters only.
	Blocked = { "admin", "moderator", "roblox", "staff", "owner", "developer" },

	Skins = {
		{ 255, 224, 196 }, { 245, 205, 170 }, { 224, 172, 126 }, { 190, 135, 90 }, { 141, 94, 62 }, { 98, 64, 44 },
	},
	HairColors = {
		{ 40, 30, 28 }, { 92, 58, 34 }, { 176, 120, 62 }, { 232, 200, 110 }, { 190, 60, 50 }, { 90, 110, 220 }, { 220, 220, 230 }, { 170, 90, 210 },
	},
	Outfits = {
		{ 200, 70, 60 }, { 230, 140, 50 }, { 235, 205, 70 }, { 90, 190, 100 }, { 60, 170, 190 }, { 80, 110, 230 }, { 150, 90, 220 }, { 230, 110, 170 }, { 90, 90, 100 }, { 235, 235, 240 },
	},
	Defaults = { Skin = 2, Hair = 2, Outfit = 6 },
}
