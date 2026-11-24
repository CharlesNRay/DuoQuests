--[[
	PremiumService (ModuleScript)
	Location: ServerScriptService > Server > Services > PremiumService

	Robux -> Sunstones. Each pack in Config/Premium is a Developer Product; Roblox calls ProcessReceipt after a purchase.
	We grant the Sunstones, record the receipt (so a repeated receipt never pays twice), save the profile, and only then
	report the purchase as granted. If anything is not ready we answer NotProcessedYet and Roblox asks again later.

	  PremiumService.Init(getProfile)
	  PremiumService.Grant(profile, productId, purchaseId) -> "Granted" | "NotProcessedYet"   (pure part, used by tests)
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Premium)
local Premium = require(Shared.Premium)
local Passes = require(Shared.Passes)
local PolicyService = game:GetService("PolicyService")

local PremiumService = {}

local packByProduct = {}
for _, pack in ipairs(Config.Packs) do
	if pack.ProductId ~= 0 then
		packByProduct[pack.ProductId] = pack
	end
end

local MAX_RECEIPTS = 200 -- remembered purchase ids per player (old ones drop off)

-- Adds the pack's Sunstones once per purchase id.
function PremiumService.Grant(profile, productId, purchaseId)
	local pack = packByProduct[productId]
	if not pack then
		return "NotProcessedYet"
	end
	local account = profile.Permanent.Premium
	if account == nil then
		Premium.AddSunstones(profile, 0) -- creates the account table
		account = profile.Permanent.Premium
	end
	account.Receipts = account.Receipts or {}
	local id = tostring(purchaseId)
	if account.Receipts[id] then
		return "Granted" -- already paid out for this purchase
	end
	local ok = Premium.AddPack(profile, pack.Id)
	if not ok then
		return "NotProcessedYet"
	end
	account.Receipts[id] = os.time()
	local count, oldest, oldestAt = 0, nil, math.huge
	for key, at in pairs(account.Receipts) do
		count += 1
		if at < oldestAt then
			oldest, oldestAt = key, at
		end
	end
	if count > MAX_RECEIPTS and oldest then
		account.Receipts[oldest] = nil
	end
	return "Granted"
end

-- Roblox restricts "paid random items" in some regions: true when this player may be offered them (fails closed).
function PremiumService.PaidRandomAllowed(player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	return ok and info ~= nil and info.ArePaidRandomItemsRestricted == false
end

-- Matches the profile's passes to what Roblox says the player owns (ignores passes with no id yet): grants owned ones and,
-- in the live game, removes ones the player no longer owns (a refund). Studio keeps them: test purchases and the
-- Test cheats toggles are not real ownership. A failed check changes nothing.
function PremiumService.SyncPasses(player, profile)
	local live = not RunService:IsStudio()
	for id, def in pairs(Config.Passes) do
		if def.GamePassId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.GamePassId)
			end)
			if ok and owns and not Passes.Has(profile, id) then
				Passes.Grant(profile, id)
			elseif ok and owns == false and live and Passes.Has(profile, id) then
				Passes.Revoke(profile, id)
			end
		end
	end
end

function PremiumService.Init(getProfile, saveNow, onGranted)
	local function syncWhenReady(player)
		task.spawn(function()
			for _ = 1, 60 do
				local profile = getProfile(player)
				if profile then
					PremiumService.SyncPasses(player, profile)
					return
				end
				task.wait(0.5)
			end
		end)
	end
	Players.PlayerAdded:Connect(syncWhenReady)
	for _, player in ipairs(Players:GetPlayers()) do
		syncWhenReady(player)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if not purchased then
			return
		end
		local profile = getProfile(player)
		for id, def in pairs(Config.Passes) do
			if profile and def.GamePassId == gamePassId then
				Passes.Grant(profile, id)
				saveNow(player)
				if onGranted then
					onGranted(player)
				end
			end
		end
	end)
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local profile = getProfile(player)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local result = PremiumService.Grant(profile, receipt.ProductId, receipt.PurchaseId)
		if result ~= "Granted" then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not saveNow(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet -- not saved yet: Roblox will call again and the receipt id keeps it from paying twice
		end
		if onGranted then
			onGranted(player)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return PremiumService
