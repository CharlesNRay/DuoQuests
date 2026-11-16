--[[
	CodesScreen (ModuleScript): redeem codes.
	  CodesScreen.Codes(container, state, call, extra)    extra.CodeResult = reply of the last RedeemCode ({ Success, Reason, Lines })

	The list of codes lives on the server only; this screen just sends the text typed into the box.
]]
local Kit = require(script.Parent.Kit)
local C = Kit.Colors

local GOOD = Color3.fromRGB(130, 235, 150)
local BAD = Color3.fromRGB(255, 130, 120)

local REASONS = {
	Empty = "Type a code first.",
	Invalid = "That code is not valid.",
	NotYet = "That code is not active yet.",
	Expired = "That code has expired.",
	AlreadyRedeemed = "You already used that code.",
	Slow = "Too many wrong tries - wait a moment and try again.",
}

local CodesScreen = {}

function CodesScreen.Codes(container, state, call, extra)
	Kit.clear(container)
	local area = Kit.frame({ Name = "CodesArea", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, NoCorner = true, Parent = container })
	Kit.label({ Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 6), Text = "Got a code from the game page, a video or an event? Type it below. Each code works once per account.", TextSize = 13, TextColor3 = C.Dim, Parent = area })

	local box = Kit.new("TextBox", {
		Name = "CodeBox", Size = UDim2.new(1, -176, 0, 44), Position = UDim2.fromOffset(8, 56), BackgroundColor3 = C.PanelLight,
		TextColor3 = C.Text, PlaceholderText = "ENTER CODE", PlaceholderColor3 = C.Dim, Text = "", ClearTextOnFocus = false,
		Font = Enum.Font.GothamBold, TextSize = 18, BorderSizePixel = 0, Parent = area,
	})
	Kit.corner(8).Parent = box
	local function submit()
		local text = box.Text
		local ok, data = call("RedeemCode", text)
		extra.CodeResult = if ok then data else nil
		-- call() already redrew the screen before the reply was stored, so draw it once more with the result
		CodesScreen.Codes(container, state, call, extra)
	end
	Kit.button({ Name = "RedeemButton", Size = UDim2.fromOffset(150, 44), Position = UDim2.new(1, -158, 0, 56), Text = "Redeem", BackgroundColor3 = GOOD, TextColor3 = Color3.fromRGB(10, 40, 18), Parent = area }, submit)
	box.FocusLost:Connect(function(enter)
		if enter then
			submit()
		end
	end)

	local r = extra.CodeResult
	if r then
		local lines = {}
		if r.Success then
			table.insert(lines, "Code redeemed! You got:")
			for _, line in ipairs(r.Lines or {}) do
				table.insert(lines, "  " .. line)
			end
		else
			table.insert(lines, (REASONS[r.Reason] or "That did not work."))
		end
		Kit.label({ Name = "CodeResult", Size = UDim2.new(1, -16, 0, 150), Position = UDim2.fromOffset(8, 112), Text = table.concat(lines, "\n"), TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = if r.Success then GOOD else BAD, Parent = area })
	end
end

return CodesScreen
