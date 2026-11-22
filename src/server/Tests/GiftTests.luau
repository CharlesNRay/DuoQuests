--[[
	GiftTests (ModuleScript)
	Location: ServerScriptService > Server > Tests > GiftTests

	Gifting Stash items between players: what can be gifted and the daily limits.   require(...GiftTests)()
]]
return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { Gifts = require(Shared.Gifts), Consumables = require(Shared.Consumables), ProfileTemplate = require(Shared.ProfileTemplate) }
	end
	local Gifts, Consumables = m.Gifts, m.Consumables
	local passed, failed = 0, 0
	local function check(name, condition)
		if condition then
			passed += 1
		else
			failed += 1
			;(warn or print)("  FAIL  " .. name)
		end
	end
	print("GiftTests")

	local now = 86400 * 100
	local a, b = m.ProfileTemplate.New(), m.ProfileTemplate.New()
	Consumables.Grant(a, "PetFood", 20)
	Consumables.Grant(a, "PetWish", 3)
	check("A gift moves the item", Gifts.Give(a, b, "PetFood", 2, now) == true and Consumables.Count(a, "PetFood") == 18 and Consumables.Count(b, "PetFood") == 2)
	check("Wish tickets cannot be gifted", select(2, Gifts.Give(a, b, "PetWish", 1, now)) == "NotGiftable")
	check("You cannot gift more than you have", select(2, Gifts.Give(a, b, "XPTonic", 1, now)) == "NotEnough")
	check("You cannot gift to yourself", select(2, Gifts.Give(a, a, "PetFood", 1, now)) == "Self")
	check("A bad count is refused", select(2, Gifts.Give(a, b, "PetFood", 0, now)) == "BadCount")
	Gifts.Give(a, b, "PetFood", 3, now)
	check("The daily send limit holds", select(2, Gifts.Give(a, b, "PetFood", 1, now)) == "SendLimit" and Gifts.Left(a, now).Send == 0)
	check("The limit resets the next day", Gifts.Give(a, b, "PetFood", 1, now + 86400) == true)
	local c = m.ProfileTemplate.New()
	Consumables.Grant(c, "PetFood", 20)
	local d = m.ProfileTemplate.New()
	Consumables.Grant(d, "PetFood", 20)
	local r = m.ProfileTemplate.New()
	Gifts.Give(c, r, "PetFood", 5, now)
	Gifts.Give(d, r, "PetFood", 5, now)
	check("The daily receive limit holds", select(2, Gifts.Give(a, r, "PetFood", 1, now + 86400 * 0)) ~= true and Gifts.Left(r, now).Receive == 0)

	print(("GiftTests done: %d passed, %d failed"):format(passed, failed))
	return passed, failed
end
