--[[
	SkillEffects (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > SkillEffects

	The look of every skill in the fight scene. client/Battle/SkillEffects draws these; nothing here changes combat.
	Colours are {r,g,b}. Every ability, pet skill and ultimate has an entry (a test fails when a new one has none).

	Abilities[abilityId] = {
	    Hit    = kind    single-target damage: what lands on the target
	    Area   = kind    area damage / area effect: drawn once over the whole enemy (or ally) side when the skill is cast
	    Heal   = kind    what appears on each healed ally
	    Shield = kind    what appears on each shielded ally
	    Buff   = kind    what appears on a buffed ally (the status decides the colour, see Statuses)
	    Color, Color2    the skill's colours
	    Glyph            optional symbol that pops up over the caster (pet skills use it over the pet)
	}

	Hit kinds     Slash, Cross, Smash, Orb, Pillar, Beam, Lightning, Shards, Flame, Claws, Burst
	Area kinds    Nova, Quake, Whirl, Rain, Wave, Starfall
	Heal kinds    Rings, Spiral, Bloom, Cross
	Shield kinds  Dome, Barrier, Bubble
	Buff kinds    Chevrons, Glyph, Pulse
	Revive kind   Rise
	Basic[classId] = the basic attack's look per class ("Enemy" for monsters)
	Statuses[statusId] = { Buff = kind, Color, Glyph? }
	Ultimates[ultimateId] = { Kind, Color, Color2 }  big shows, drawn in code per Kind (Charge, Dawn, Judgment, Generic)
]]

local function A(t)
	return t
end

return {
	Kinds = {
		Hit = { Slash = true, Cross = true, Smash = true, Orb = true, Pillar = true, Beam = true, Lightning = true, Shards = true, Flame = true, Claws = true, Burst = true },
		Area = { Nova = true, Quake = true, Whirl = true, Rain = true, Wave = true, Starfall = true },
		Heal = { Rings = true, Spiral = true, Bloom = true, Cross = true },
		Shield = { Dome = true, Barrier = true, Bubble = true },
		Buff = { Chevrons = true, Glyph = true, Pulse = true },
		Revive = { Rise = true },
		Ultimate = { Charge = true, Dawn = true, Judgment = true, Generic = true },
	},

	Basic = {
		Warrior = { Hit = "Slash", Color = { 235, 235, 245 }, Color2 = { 255, 170, 120 } },
		Cleric = { Hit = "Burst", Color = { 255, 240, 160 }, Color2 = { 255, 255, 255 } },
		Mage = { Hit = "Orb", Color = { 150, 150, 255 }, Color2 = { 220, 190, 255 } },
		Enemy = { Hit = "Burst", Color = { 235, 120, 110 }, Color2 = { 255, 220, 200 } },
	},

	Statuses = {
		Shield = { Shield = "Dome", Color = { 150, 210, 255 } },
		Fortified = { Buff = "Chevrons", Color = { 120, 170, 255 } },
		IronSkin = { Buff = "Chevrons", Color = { 170, 180, 200 } },
		Taunting = { Buff = "Glyph", Color = { 255, 90, 80 }, Glyph = "❗" },
		LastStand = { Buff = "Pulse", Color = { 255, 80, 60 } },
		GuardianAngel = { Buff = "Glyph", Color = { 255, 245, 190 }, Glyph = "👼" },
		Rallied = { Buff = "Glyph", Color = { 255, 200, 90 }, Glyph = "📣" },
		Blessed = { Buff = "Glyph", Color = { 255, 235, 150 }, Glyph = "✦" },
		ArcaneSurge = { Buff = "Pulse", Color = { 170, 140, 255 } },
		Frenzied = { Buff = "Chevrons", Color = { 255, 120, 70 } },
		Unbreakable = { Buff = "Pulse", Color = { 255, 215, 100 } },
		Aegis = { Shield = "Barrier", Color = { 255, 235, 150 } },
		Chilled = { Buff = "Glyph", Color = { 150, 220, 255 }, Glyph = "❄" },
		Enraged = { Buff = "Pulse", Color = { 255, 70, 60 } },
	},

	Abilities = {
		-- Warrior: steel, red and orange
		ShieldBash = A({ Hit = "Smash", Color = { 215, 220, 235 }, Color2 = { 255, 190, 120 } }),
		Taunt = A({ Buff = "Glyph", Color = { 255, 90, 80 }, Glyph = "❗" }),
		IronSkin = A({ Buff = "Chevrons", Color = { 170, 180, 200 } }),
		Whirlwind = A({ Area = "Whirl", Color = { 240, 240, 250 }, Color2 = { 255, 160, 90 } }),
		ShieldWall = A({ Shield = "Barrier", Color = { 130, 175, 235 } }),
		LastStand = A({ Buff = "Pulse", Color = { 255, 80, 60 } }),
		RallyingCry = A({ Buff = "Glyph", Color = { 255, 200, 90 }, Glyph = "📣" }),
		BloodFrenzy = A({ Buff = "Chevrons", Color = { 230, 60, 50 } }),
		Bulwark = A({ Shield = "Barrier", Color = { 255, 215, 110 } }),
		Cleave = A({ Area = "Wave", Color = { 235, 70, 60 }, Color2 = { 255, 200, 160 } }),
		ExecutionerStrike = A({ Hit = "Cross", Color = { 170, 20, 30 }, Color2 = { 255, 120, 100 } }),
		Retribution = A({ Hit = "Slash", Color = { 255, 215, 110 }, Color2 = { 255, 255, 220 }, Heal = "Spiral" }),
		UnbreakableVow = A({ Buff = "Pulse", Color = { 255, 215, 100 } }),
		-- Cleric: gold, white and soft green
		Smite = A({ Hit = "Pillar", Color = { 255, 235, 140 }, Color2 = { 255, 255, 255 } }),
		Heal = A({ Heal = "Rings", Color = { 110, 235, 140 }, Color2 = { 220, 255, 220 } }),
		Blessing = A({ Buff = "Glyph", Color = { 255, 235, 150 }, Glyph = "✦" }),
		RadiantBurst = A({ Area = "Nova", Color = { 255, 230, 120 }, Color2 = { 255, 255, 255 }, Heal = "Cross" }),
		DivineShield = A({ Shield = "Dome", Color = { 255, 235, 150 } }),
		GroupHeal = A({ Heal = "Bloom", Color = { 130, 240, 160 }, Color2 = { 255, 190, 220 } }),
		GuardianAngel = A({ Buff = "Glyph", Color = { 255, 245, 190 }, Glyph = "👼" }),
		Judgment = A({ Hit = "Beam", Color = { 255, 245, 200 }, Color2 = { 255, 215, 100 } }),
		Resurrection = A({ Revive = "Rise", Color = { 255, 240, 150 } }),
		Sanctuary = A({ Heal = "Spiral", Shield = "Dome", Color = { 190, 255, 200 }, Color2 = { 255, 245, 180 } }),
		Renewal = A({ Heal = "Spiral", Color = { 140, 235, 120 }, Color2 = { 220, 255, 190 } }),
		HolyAegis = A({ Shield = "Barrier", Heal = "Cross", Color = { 255, 235, 150 }, Color2 = { 255, 255, 255 } }),
		HolyWrath = A({ Area = "Starfall", Color = { 255, 215, 90 }, Color2 = { 255, 250, 210 } }),
		DivineSmite = A({ Hit = "Pillar", Color = { 255, 255, 255 }, Color2 = { 255, 215, 100 } }),
		-- Mage: fire, frost, lightning, arcane
		Fireball = A({ Hit = "Flame", Color = { 255, 130, 50 }, Color2 = { 255, 220, 100 } }),
		Blizzard = A({ Area = "Rain", Color = { 150, 220, 255 }, Color2 = { 235, 250, 255 } }),
		LightningBolt = A({ Hit = "Lightning", Color = { 255, 245, 130 }, Color2 = { 160, 210, 255 } }),
		ArcaneSurge = A({ Buff = "Pulse", Color = { 170, 140, 255 } }),
		-- monsters
		CrushingBlow = A({ Hit = "Smash", Color = { 200, 150, 110 }, Color2 = { 255, 220, 160 } }),
		SlimeSplit = A({ Area = "Nova", Color = { 120, 220, 130 }, Color2 = { 220, 255, 200 } }),
		Enrage = A({ Buff = "Pulse", Color = { 255, 70, 60 } }),
		SporeBurst = A({ Area = "Nova", Color = { 170, 230, 110 }, Color2 = { 230, 255, 170 } }),
		SporeCall = A({ Area = "Nova", Color = { 150, 200, 110 }, Color2 = { 220, 240, 170 } }),
		-- pet skills (the glyph pops up over the pet)
		Pet_Slimey = A({ Shield = "Bubble", Color = { 100, 200, 120 }, Glyph = "💧" }),
		Pet_Foxling = A({ Hit = "Flame", Color = { 230, 120, 50 }, Color2 = { 255, 200, 110 }, Glyph = "🔥" }),
		Pet_Mossback = A({ Buff = "Chevrons", Color = { 80, 150, 100 }, Glyph = "🌿" }),
		Pet_Pebbles = A({ Area = "Quake", Color = { 140, 130, 120 }, Color2 = { 200, 190, 170 }, Glyph = "⛰" }),
		Pet_Cottonpuff = A({ Heal = "Bloom", Color = { 220, 230, 245 }, Color2 = { 255, 255, 255 }, Glyph = "☁" }),
		Pet_Chirpy = A({ Buff = "Glyph", Color = { 230, 180, 80 }, Glyph = "🎵" }),
		Pet_Wisp = A({ Hit = "Lightning", Color = { 230, 220, 90 }, Color2 = { 255, 255, 200 }, Glyph = "⚡" }),
		Pet_Emberkit = A({ Hit = "Claws", Color = { 220, 90, 50 }, Color2 = { 255, 180, 90 }, Glyph = "🐾" }),
		Pet_Shellby = A({ Shield = "Dome", Color = { 70, 140, 200 }, Glyph = "🐚" }),
		Pet_Zephyr = A({ Buff = "Chevrons", Color = { 120, 200, 190 }, Glyph = "💨" }),
		Pet_Frostwing = A({ Area = "Rain", Color = { 120, 190, 235 }, Color2 = { 230, 248, 255 }, Glyph = "❄" }),
		Pet_Starbun = A({ Heal = "Rings", Color = { 240, 220, 120 }, Color2 = { 255, 255, 220 }, Glyph = "🌠" }),
		Pet_Thornback = A({ Shield = "Barrier", Color = { 90, 140, 70 }, Glyph = "🌵" }),
		Pet_EmberDrake = A({ Area = "Wave", Color = { 235, 80, 40 }, Color2 = { 255, 190, 80 }, Glyph = "🐲" }),
		Pet_Colossling = A({ Area = "Quake", Color = { 150, 110, 80 }, Color2 = { 220, 180, 130 }, Glyph = "👣" }),
		Pet_Crownling = A({ Area = "Starfall", Shield = "Dome", Color = { 255, 205, 80 }, Color2 = { 255, 245, 190 }, Glyph = "👑" }),
		Pet_Laurelwing = A({ Buff = "Chevrons", Color = { 150, 210, 110 }, Glyph = "🏆" }),
		Pet_Bannerhound = A({ Shield = "Barrier", Color = { 210, 90, 80 }, Glyph = "🚩" }),
		Pet_Haloette = A({ Heal = "Cross", Color = { 250, 235, 160 }, Color2 = { 255, 255, 255 }, Glyph = "⭐" }),
		Pet_Aurora = A({ Heal = "Spiral", Shield = "Dome", Color = { 140, 200, 220 }, Color2 = { 200, 255, 220 }, Glyph = "🌈" }),
	},

	Ultimates = {
		SanctifiedCharge = { Kind = "Charge", Color = { 255, 225, 120 }, Color2 = { 255, 255, 255 } },
		BulwarkOfDawn = { Kind = "Dawn", Color = { 255, 190, 110 }, Color2 = { 255, 245, 200 } },
		RadiantJudgment = { Kind = "Judgment", Color = { 255, 245, 190 }, Color2 = { 255, 200, 90 } },
	},
	DefaultUltimate = { Kind = "Generic", Color = { 190, 110, 255 }, Color2 = { 255, 255, 255 } },
}
