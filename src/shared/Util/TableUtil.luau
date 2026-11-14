--[[
	TableUtil (ModuleScript)
	Location: ReplicatedStorage > Shared > Util > TableUtil

	Small helpers used by the data layer.
]]

local TableUtil = {}

-- Returns a fully independent copy of a table (nested tables are copied too).
function TableUtil.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in pairs(value) do
		copy[key] = TableUtil.DeepCopy(inner)
	end
	return copy
end

-- Fills in any keys that exist in `template` but are missing from `target`.
-- Existing values are never overwritten, so saved player data always wins.
-- Used after loading so older profiles gain fields added in later updates.
function TableUtil.Reconcile(target, template)
	for key, templateValue in pairs(template) do
		local current = target[key]
		if current == nil then
			target[key] = TableUtil.DeepCopy(templateValue)
		elseif type(current) == "table" and type(templateValue) == "table" then
			TableUtil.Reconcile(current, templateValue)
		end
	end
	return target
end

return TableUtil
