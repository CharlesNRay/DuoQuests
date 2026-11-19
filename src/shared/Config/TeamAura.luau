--[[
	TeamAura (ModuleScript, data only)
	Location: ReplicatedStorage > Shared > Config > TeamAura

	A full team bonus (2026-11-19): a fight whose heroes include at least one tank, one healer and two damage dealers
	(class Role in Config/Classes) gives every hero these multipliers for the whole fight. Companions fill missing roles
	first (Party.SyncCompanions), so a lone player usually has it; a party of four friends has to pick its classes for it.
]]
return {
	Needs = { Tank = 1, Healer = 1, Damage = 2 },
	Mult = { MaxHealth = 1.06, Attack = 1.06, Defense = 1.06 },
}
