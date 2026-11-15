--[[
	Rng (ModuleScript)
	Location: ReplicatedStorage > Shared > Combat > Rng

	Small seeded random number generator (Park-Miller). Given the same seed it
	always produces the same sequence, which makes fights reproducible for
	tests, bug reports and (later) client-side replays.

	  local roll = Rng.new(42)
	  roll() --> number strictly between 0 and 1
]]

local Rng = {}

local MODULUS = 2147483647
local MULTIPLIER = 16807

function Rng.new(seed)
	local state = math.floor(math.abs(seed)) % MODULUS
	if state == 0 then
		state = 1
	end
	return function()
		state = (state * MULTIPLIER) % MODULUS
		return state / MODULUS
	end
end

return Rng
