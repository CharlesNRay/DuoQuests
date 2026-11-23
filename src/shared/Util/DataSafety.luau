--[[
	DataSafety (ModuleScript): can this value be stored in a Roblox DataStore (and sent over a remote)?

	DataStores store JSON. A table must be either an array (keys 1..n, no gaps) or a dictionary with only string keys;
	numbers must be finite; no functions, userdata (Vector3, Instance ...) or threads. A profile that breaks a rule fails
	EVERY save, and Studio's in-memory fallback never notices. (We were bitten by number-keyed tables with gaps before:
	pet gear Equipped, StageClaims.) The total must stay under the DataStore limit (4 MB).

	  DataSafety.Problems(value, maxProblems?) -> list of "path: what is wrong" (empty when safe)
	  DataSafety.Size(value)                   -> approximate JSON length in characters
	  DataSafety.LIMIT                         -> 4194304
]]
local DataSafety = {}

DataSafety.LIMIT = 4194304

local function isArray(t)
	local n = #t
	local count = 0
	for k in pairs(t) do
		if type(k) ~= "number" or k ~= math.floor(k) or k < 1 or k > n then
			return false
		end
		count += 1
	end
	return count == n
end

function DataSafety.Problems(value, maxProblems)
	maxProblems = maxProblems or 20
	local problems = {}
	local seen = {}
	local function add(path, what)
		if #problems < maxProblems then
			table.insert(problems, path .. ": " .. what)
		end
	end
	local function walk(v, path)
		local t = type(v)
		if t == "number" then
			if v ~= v or v == math.huge or v == -math.huge then
				add(path, "number is NaN or infinite")
			end
		elseif t == "string" or t == "boolean" or t == "nil" then
			return
		elseif t == "table" then
			if seen[v] then
				add(path, "table appears twice (a cycle or a shared table)")
				return
			end
			seen[v] = true
			if next(v) == nil then
				return
			end
			if isArray(v) then
				for i, item in ipairs(v) do
					walk(item, path .. "[" .. i .. "]")
				end
				return
			end
			local hasString, hasOther = false, false
			for k in pairs(v) do
				if type(k) == "string" then
					hasString = true
				else
					hasOther = true
				end
			end
			if hasOther then
				local example
				for k in pairs(v) do
					if type(k) ~= "string" then
						example = k
						break
					end
				end
				add(path, (if hasString then "mixes string and non-string keys" else "has non-string keys that are not a gap-free array") .. " (e.g. " .. tostring(example) .. ")")
			end
			for k, item in pairs(v) do
				walk(item, path .. "." .. tostring(k))
			end
		else
			add(path, "cannot store a " .. t)
		end
	end
	walk(value, "profile")
	return problems
end

-- an approximate JSON length (close enough to watch the 4 MB limit)
function DataSafety.Size(value)
	local t = type(value)
	if t == "number" then
		return #tostring(value)
	elseif t == "string" then
		return #value + 2
	elseif t == "boolean" then
		return if value then 4 else 5
	elseif t == "table" then
		local n = 2
		for k, v in pairs(value) do
			n += (if type(k) == "string" then #k + 3 else 0) + DataSafety.Size(v) + 1
		end
		return n
	end
	return 4
end

return DataSafety
