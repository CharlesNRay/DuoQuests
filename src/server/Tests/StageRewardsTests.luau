--[[
	StageRewardsTests (ModuleScript): every cleared stage leaves a reward on the map; bosses always include wishes.
	  require(game.ServerScriptService.Server.Tests.StageRewardsTests)()
]]
return function(modulesOverride)
	local m = modulesOverride
	if m == nil then
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		m = { StageRewards = require(Shared.StageRewards), ProfileTemplate = require(Shared.ProfileTemplate), Consumables = require(Shared.Consumables), Stages = require(Shared.Stages) }
	end
	local StageRewards, ProfileTemplate, Consumables, Stages = m.StageRewards, m.ProfileTemplate, m.Consumables, m.Stages
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

	local p = ProfileTemplate.New()
	p.Season.HighestStage = 1
	check("Nothing is ready before a stage is cleared", StageRewards.Status(p, 1) == "Locked" and StageRewards.ReadyCount(p) == 0)
	check("A locked stage cannot be claimed", select(2, StageRewards.Claim(p, 1)) == "NotCleared")

	p.Season.HighestStage = 12 -- stages 1..11 are cleared
	check("Cleared stages are ready", StageRewards.Status(p, 5) == "Ready" and StageRewards.ReadyCount(p) == 11)
	check("The frontier stage itself is not ready yet", StageRewards.Status(p, 12) == "Locked")

	for stage = 1, 60 do
		local r = StageRewards.For(stage)
		check("Stage " .. stage .. " pays gold, shards and a Wishstone", r.Gold > 0 and r.Shards > 0 and r.Wishstones >= 1)
		if Stages.IsBoss(stage) then
			check("Boss stage " .. stage .. " always pays a Pet Wish and a Skill Wish", r.PetWish >= 1 and r.SkillWish >= 1)
		end
	end

	local gold, stones = p.Season.Currencies.Gold, p.Season.Currencies.Wishstones or 0
	local ok, r = StageRewards.Claim(p, 3)
	check("Claiming pays the reward", ok and p.Season.Currencies.Gold == gold + r.Gold and (p.Season.Currencies.Wishstones or 0) == stones + r.Wishstones)
	check("A stage can only be claimed once", select(2, StageRewards.Claim(p, 3)) == "AlreadyClaimed" and StageRewards.Status(p, 3) == "Claimed")

	local pet, skill = Consumables.Count(p, "PetWish"), Consumables.Count(p, "SkillWish")
	local okBoss, boss = StageRewards.Claim(p, 10)
	check("Claiming boss 10 grants wish tickets", okBoss and Consumables.Count(p, "PetWish") == pet + boss.PetWish and Consumables.Count(p, "SkillWish") == skill + boss.SkillWish)

	local okAll, total = StageRewards.ClaimAll(p)
	check("Claim all takes everything still waiting", okAll and total.Count == 9 and StageRewards.ReadyCount(p) == 0)
	check("Claim all again does nothing", select(2, StageRewards.ClaimAll(p)).Count == 0)
	check("A bad stage is refused", select(2, StageRewards.Claim(p, 0)) == "BadStage" and select(2, StageRewards.Claim(p, "x")) == "BadStage")
	check("The reward text names the wishes on a boss", StageRewards.Text(10):find("Pet Wish") ~= nil and StageRewards.Text(9):find("Pet Wish") == nil)
	print(("StageRewardsTests done: %d passed, %d failed"):format(passed, failed))
end
