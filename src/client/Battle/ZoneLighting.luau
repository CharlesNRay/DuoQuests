--[[
	ZoneLighting (ModuleScript): the sky and light follow the zone while you are in battle view (this client only).

	Night zones (Glimmer Cave, Void Rift, Astral Expanse...) get a night sky, storm and fire zones dusk, the deep a teal
	haze, and every zone tints the air with its Sky colour. Leaving battle view fades back to the town's normal light.
	Zone fields (Config/Zones): ClockTime (0-24, default 14), Haze (0-1 how thick the tinted air is, default 0.25).

	  ZoneLighting.Apply(theme)   fade to that zone's look (call again when the watched zone changes)
	  ZoneLighting.Clear()        fade back to what Lighting was before the first Apply
]]
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local ZoneLighting = {}

local saved = nil -- Lighting as it was before battle view
local atmosphere = nil
local current = nil

local function color(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function ensureAtmosphere()
	if atmosphere and atmosphere.Parent then
		return atmosphere
	end
	atmosphere = Lighting:FindFirstChild("DQ_ZoneAir") or Instance.new("Atmosphere")
	atmosphere.Name = "DQ_ZoneAir"
	if not atmosphere.Parent then
		atmosphere.Density = 0
		atmosphere.Offset = 0.1
		atmosphere.Glare = 0
		atmosphere.Haze = 0
		atmosphere.Parent = Lighting
	end
	return atmosphere
end

function ZoneLighting.Apply(theme)
	if not theme or current == theme.Name then
		return
	end
	current = theme.Name
	if not saved then
		saved = {
			ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient, ExposureCompensation = Lighting.ExposureCompensation,
		}
	end
	local sky = color(theme.Sky)
	local clock = theme.ClockTime or 14
	local night = clock < 6 or clock > 19.5
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		ClockTime = clock,
		-- night zones keep a bright, tinted fill light so the fighters stay easy to read against the dark sky
		Brightness = math.clamp(theme.Brightness or 2, if night then 1.8 else 0.8, 3.2),
		Ambient = if night then sky:Lerp(Color3.new(1, 1, 1), 0.45) else sky:Lerp(Color3.new(0, 0, 0), 0.55),
		OutdoorAmbient = if night then sky:Lerp(Color3.new(1, 1, 1), 0.55) else sky:Lerp(Color3.new(1, 1, 1), 0.25),
		ExposureCompensation = if night then 0.9 else 0,
	}):Play()
	local air = ensureAtmosphere()
	TweenService:Create(air, info, {
		Density = theme.Haze or 0.25,
		Color = sky:Lerp(Color3.new(1, 1, 1), 0.2),
		Decay = sky:Lerp(Color3.new(0, 0, 0), 0.3),
		Haze = if night then 1 else 0.6,
	}):Play()
end

function ZoneLighting.Clear()
	current = nil
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Sine)
	if saved then
		TweenService:Create(Lighting, info, { ClockTime = saved.ClockTime, Brightness = saved.Brightness, Ambient = saved.Ambient, OutdoorAmbient = saved.OutdoorAmbient, ExposureCompensation = saved.ExposureCompensation }):Play()
		saved = nil
	end
	if atmosphere and atmosphere.Parent then
		TweenService:Create(atmosphere, info, { Density = 0, Haze = 0 }):Play()
	end
end

return ZoneLighting
