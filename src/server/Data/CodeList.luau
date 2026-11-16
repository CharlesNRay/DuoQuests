--[[
	CodeList (ModuleScript, data only, SERVER ONLY)
	Location: ServerScriptService > Server > Data > CodeList

	Redeem codes. This lives on the server on purpose: clients can read everything in ReplicatedStorage, so a list
	kept there would hand every code to every player (and to exploiters). Codes are typed in the Codes screen and
	are checked by Shared/Codes.

	  [CODE] = {                     CODE: capital letters and digits only
	      Rewards = {                every field is optional
	          Sunstones = n,         permanent premium currency (earned, never random)
	          Wishstones = n,        this season's blue currency
	          SkillPicks = n,
	          Items = { [consumableId] = n },     boosts, pet food, wish tickets (see Config/Consumables)
	          Titles = { "text" },   Cosmetics = { "Aura_Flame" },    (see Config/Cosmetics)
	      },
	      StartsAt = unix seconds?,  ExpiresAt = unix seconds?,       (outside that window the code is refused)
	      Disabled = true?,          switch a code off without deleting it
	  }

	Each code can be redeemed once per account. Codes with a global use limit would need a DataStore counter: not built.
	Sample codes: replace them with your own before launch.
]]

return {
	WELCOME = { Rewards = { Items = { PetWish = 3, SkillWish = 3, XPTonic = 3, PetFood = 5 } } },
	DUOQUEST = { Rewards = { Items = { PetWish = 10, IronTonic = 2, HasteDraught = 2 } } },
	THANKS = { Rewards = { Items = { SkillWish = 10, PowerElixir = 2, GrandPetFood = 1 } } },
	SEASON1 = { Rewards = { Items = { PetWish = 2, SkillWish = 2, XPTonic = 2, PowerElixir = 2 } }, ExpiresAt = 1801440000 },
}
