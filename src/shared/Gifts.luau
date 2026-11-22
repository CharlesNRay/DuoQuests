--[[
	Gifts (ModuleScript)
	Location: ReplicatedStorage > Shared > Gifts

	Gifting (2026-11-22): give Stash items to a party member or guild mate who is online on the same server. Only everyday
	items can be gifted (pet food and boosts, not wish tickets), with a daily limit for sending and for receiving, so alt
	accounts cannot funnel progress. Pure: the server checks who may receive (online, same party or guild) before this.

	  Gifts.Give(fromProfile, toProfile, itemId, count, now) -> true, sentToday  |  false, reason
	      reasons: "NotGiftable", "BadCount", "NotEnough", "SendLimit", "ReceiveLimit", "Self"
	  Gifts.Left(profile, now) -> { Send = n, Receive = n }
]]
local Consumables = require(script.Parent.Consumables)

local Gifts = {}

Gifts.Giftable = { PetFood = true, GrandPetFood = true, XPTonic = true, PowerElixir = true, IronTonic = true, HasteDraught = true }
Gifts.SendPerDay = 5 -- items a player can give away per day
Gifts.ReceivePerDay = 10 -- items a player can receive per day

local function today(now)
	return math.floor(now / 86400)
end

local function book(profile, now)
	local g = profile.Season.Gifts
	if g == nil or g.Day ~= today(now) then
		g = { Day = today(now), Sent = 0, Got = 0 }
		profile.Season.Gifts = g
	end
	return g
end

function Gifts.Left(profile, now)
	local g = book(profile, now)
	return { Send = Gifts.SendPerDay - g.Sent, Receive = Gifts.ReceivePerDay - g.Got }
end

function Gifts.Give(fromProfile, toProfile, itemId, count, now)
	if fromProfile == toProfile then
		return false, "Self"
	end
	if not Gifts.Giftable[itemId] then
		return false, "NotGiftable"
	end
	count = math.floor(tonumber(count) or 0)
	if count < 1 then
		return false, "BadCount"
	end
	if Consumables.Count(fromProfile, itemId) < count then
		return false, "NotEnough"
	end
	local sent, got = book(fromProfile, now), book(toProfile, now)
	if sent.Sent + count > Gifts.SendPerDay then
		return false, "SendLimit"
	end
	if got.Got + count > Gifts.ReceivePerDay then
		return false, "ReceiveLimit"
	end
	fromProfile.Season.Stash[itemId] -= count
	Consumables.Grant(toProfile, itemId, count)
	sent.Sent += count
	got.Got += count
	return true, sent.Sent
end

return Gifts
