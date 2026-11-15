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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Premium)
local Premium = require(Shared.Premium)

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

function PremiumService.Init(getProfile, saveNow, onGranted)
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
