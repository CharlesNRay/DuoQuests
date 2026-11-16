--[[
	NumberFormat (ModuleScript): short numbers for big values.
	  NumberFormat.Short(n)    1234 -> "1,234", 45600 -> "45.6K", 1250000 -> "1.25M" (K, M, B, T, Qa, Qi)
	  NumberFormat.Commas(n)   1234567 -> "1,234,567"
]]
local NumberFormat = {}

local SUFFIX = { "K", "M", "B", "T", "Qa", "Qi" }

function NumberFormat.Commas(n)
	local s = tostring(math.floor((n or 0) + 0.5))
	while true do
		local nxt, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = nxt
		if k == 0 then
			break
		end
	end
	return s
end

function NumberFormat.Short(n)
	n = n or 0
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 10000 then
		return sign .. NumberFormat.Commas(n)
	end
	local index = 0
	while n >= 1000 and index < #SUFFIX do
		n /= 1000
		index += 1
	end
	local text = if n >= 100 then ("%d"):format(math.floor(n)) elseif n >= 10 then ("%.1f"):format(math.floor(n * 10) / 10) else ("%.2f"):format(math.floor(n * 100) / 100)
	return sign .. text:gsub("%.?0+$", "") .. SUFFIX[index]
end

return NumberFormat
