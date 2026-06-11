-- UITheme.lua — Consistent design system for all UI elements
local UITheme = {}

UITheme.COLORS = {
	bg        = Color3.fromRGB(15, 17, 26),
	panel     = Color3.fromRGB(24, 27, 40),
	panel2    = Color3.fromRGB(35, 38, 56),
	accent    = Color3.fromRGB(75, 210, 115),
	accentDim = Color3.fromRGB(48, 140, 80),
	gold      = Color3.fromRGB(255, 200, 45),
	red       = Color3.fromRGB(230, 65, 55),
	text      = Color3.fromRGB(235, 238, 248),
	textDim   = Color3.fromRGB(150, 158, 180),
	combo     = Color3.fromRGB(255, 218, 55),
	crit      = Color3.fromRGB(255, 145, 35),
	xpBar     = Color3.fromRGB(100, 180, 255),
	layer = {
		Color3.fromRGB(75, 210, 75),    -- 1 green
		Color3.fromRGB(220, 190, 45),   -- 2 gold
		Color3.fromRGB(80, 220, 235),   -- 3 crystal
		Color3.fromRGB(165, 80, 225),   -- 4 shadow
		Color3.fromRGB(255, 118, 35),   -- 5 volcano
		Color3.fromRGB(195, 228, 255),  -- 6 sky
	},
}

UITheme.FONTS = {
	header  = Enum.Font.GothamBold,
	body    = Enum.Font.Gotham,
	display = Enum.Font.GothamBlack,
}

UITheme.CORNER    = UDim.new(0, 8)
UITheme.CORNER_LG = UDim.new(0, 14)

-- Helper: apply corner radius to a Frame/Button
function UITheme.applyCorner(instance, radiusOverride)
	local c = Instance.new("UICorner")
	c.CornerRadius = radiusOverride or UITheme.CORNER
	c.Parent = instance
end

-- Helper: apply stroke to a Frame
function UITheme.applyStroke(instance, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(55, 60, 90)
	s.Thickness = thickness or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = instance
end

return UITheme
