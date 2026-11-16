--[[
	Codes (ModuleScript)
	Location: ReplicatedStorage > Shared > Codes

	Redeem codes: the rules and the payout. The list of codes is NOT here: the server passes it in (server/Data/CodeList),
	so clients never see it.

	  Codes.Normalize(text)                       -> "ABC123"   (capitals and digits only, at most 24 characters) | ""
	  Codes.Redeemed(profile, code)               -> boolean
	  Codes.Redeem(profile, text, now, list)      -> true, { Lines = { "text" }, Rewards } | false, "Empty" | "Invalid" | "NotYet" | "Expired" | "AlreadyRedeemed"
	  Codes.Describe(rewards)                     -> list of short texts ("🔶 25 Sunstones", ...)
]]

local Consumables = require(script.Parent.Consumables)
local ConsumableConfig = require(script.Parent.Config.Consumables)
local Cosmetics = require(script.Parent.Cosmetics)
local Premium = require(script.Parent.Premium)

local Codes = {}

local MAX_LENGTH = 24

function Codes.Normalize(text)
	if type(text) ~= "string" then
		return ""
	end
	return (text:upper():gsub("[^A-Z0-9]", "")):sub(1, MAX_LENGTH)
end

local function ledger(profile)
	local a = profile.Permanent.Codes
	if a == nil then
		a = { Redeemed = {} }
		profile.Permanent.Codes = a
	end
	a.Redeemed = a.Redeemed or {}
	return a.Redeemed
end

function Codes.Redeemed(profile, code)
	return ledger(profile)[code] ~= nil
end

function Codes.Describe(rewards)
	local lines = {}
	if (rewards.Sunstones or 0) > 0 then
		table.insert(lines, ("🔶 %d Sunstones"):format(rewards.Sunstones))
	end
	if (rewards.Wishstones or 0) > 0 then
		table.insert(lines, ("💎 %d Wishstones"):format(rewards.Wishstones))
	end
	if (rewards.SkillPicks or 0) > 0 then
		table.insert(lines, ("%d free skill pick%s"):format(rewards.SkillPicks, if rewards.SkillPicks == 1 then "" else "s"))
	end
	local ids = {}
	for id in pairs(rewards.Items or {}) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local def = ConsumableConfig.Defs[id]
		table.insert(lines, ("%s x%d"):format(def and def.DisplayName or id, rewards.Items[id]))
	end
	for _, title in ipairs(rewards.Titles or {}) do
		table.insert(lines, 'Title "' .. title .. '"')
	end
	for _, id in ipairs(rewards.Cosmetics or {}) do
		local def = Cosmetics.Def(id)
		table.insert(lines, def and def.Name or id)
	end
	return lines
end

local function pay(profile, rewards)
	if (rewards.Sunstones or 0) > 0 then
		Premium.AddSunstones(profile, rewards.Sunstones)
	end
	local currencies = profile.Season.Currencies
	if (rewards.Wishstones or 0) > 0 then
		currencies.Wishstones = (currencies.Wishstones or 0) + rewards.Wishstones
	end
	if (rewards.SkillPicks or 0) > 0 then
		currencies.SkillPicks = (currencies.SkillPicks or 0) + rewards.SkillPicks
	end
	for id, count in pairs(rewards.Items or {}) do
		Consumables.Grant(profile, id, count)
	end
	for _, title in ipairs(rewards.Titles or {}) do
		Cosmetics.GrantTitle(profile, title)
	end
	for _, id in ipairs(rewards.Cosmetics or {}) do
		Cosmetics.Grant(profile, id)
	end
end

function Codes.Redeem(profile, text, now, list)
	local code = Codes.Normalize(text)
	if code == "" then
		return false, "Empty"
	end
	local def = list[code]
	if def == nil or def.Disabled then
		return false, "Invalid"
	end
	if def.StartsAt and now < def.StartsAt then
		return false, "NotYet"
	end
	if def.ExpiresAt and now >= def.ExpiresAt then
		return false, "Expired"
	end
	if Codes.Redeemed(profile, code) then
		return false, "AlreadyRedeemed"
	end
	ledger(profile)[code] = now
	pay(profile, def.Rewards or {})
	return true, { Lines = Codes.Describe(def.Rewards or {}), Rewards = def.Rewards }
end

return Codes
