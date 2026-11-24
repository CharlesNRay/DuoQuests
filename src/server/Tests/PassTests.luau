--[[
	PassTests (ModuleScript): Game Pass perks (shared/Passes): ownership, perk sums and the hooks into the bag and dungeon keys.
	  require(game.ServerScriptService.Server.Tests.PassTests)()
]]
return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Passes = require(Shared.Passes), Gear = require(Shared.Gear), Activities = require(Shared.Activities), Characters = require(Shared.Characters), ProfileTemplate = require(Shared.ProfileTemplate), TableUtil = require(Shared.Util.TableUtil) }
	end
	local Passes, Gear, Activities, ProfileTemplate, TableUtil = m.Passes, m.Gear, m.Activities, m.ProfileTemplate, m.TableUtil
	local warnFn = warn or print
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
			print("  PASS  " .. name)
		else
			failed += 1
			warnFn("  FAIL  " .. name)
		end
	end

	local plain, vip = ProfileTemplate.New(), ProfileTemplate.New()
	check("Not owned at first", not Passes.Has(plain, "VIP"))
	check("No perks without a pass", Passes.Perks(plain).GoldGain == 0 and Passes.Perks(plain).BagSlots == 0)
	check("Grant works", Passes.Grant(vip, "VIP") and Passes.Has(vip, "VIP"))
	check("Granting twice is harmless", Passes.Grant(vip, "VIP") and Passes.Has(vip, "VIP"))
	local ok, reason = Passes.Grant(vip, "Nope")
	check("An unknown pass is refused", ok == false and reason == "BadPass")
	check("Perks apply (gold and the pet slot, no XP bonus)", Passes.Perks(vip).GoldGain > 0 and Passes.Perks(vip).PetSlots == 1 and Passes.Perks(vip).XPGain == 0)
	check("The bag is bigger", Gear.Cap(vip) == Gear.Cap(plain) + Passes.Perks(vip).BagSlots)
	local day = 86400 * 10
	check("More dungeon keys", Activities.Of(vip, day).MaxKeys == Activities.Of(plain, day).MaxKeys + Passes.Perks(vip).DungeonKeys)
	local function find(list, id)
		for _, p in ipairs(list) do
			if p.Id == id then
				return p
			end
		end
	end
	check("The list shows ownership", find(Passes.List(vip), "VIP").Owned and not find(Passes.List(plain), "VIP").Owned)
	-- Extra Character Slots: 2 -> 4
	local Characters = m.Characters
	if Characters then
		local p = ProfileTemplate.New()
		check("2 character slots without the pass", Characters.Max(p) == 2 and Passes.Perks(p).CharacterSlots == 0)
		check("Create 2", Characters.Create(p, "Warrior") and Characters.Create(p, "Cleric"))
		local ok3, why3 = Characters.Create(p, "Mage")
		check("A 3rd is refused without the pass", ok3 == false and why3 == "Full")
		check("The pass is in the list", find(Passes.List(p), "CharacterSlots") ~= nil and not find(Passes.List(p), "CharacterSlots").Owned)
		Passes.Grant(p, "CharacterSlots")
		check("4 character slots with the pass", Characters.Max(p) == 4)
		check("3rd and 4th can be made", Characters.Create(p, "Mage") and Characters.Create(p, "Ranger"))
		local ok5, why5 = Characters.Create(p, "Rogue")
		check("A 5th is refused", ok5 == false and why5 == "Full" and #Characters.List(p) == 4)
		check("The pass gives no other perks", Passes.Perks(p).GoldGain == 0 and Passes.Perks(p).BagSlots == 0)
	else
		check("Characters module given to PassTests", false)
	end
	print(("PassTests done: %d passed, %d failed"):format(passed, failed))
end
