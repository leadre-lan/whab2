-- UITheme.lua — Design-System (dunkles Cyber-Theme passend zur Neon-Lobby)
local UITheme = {}

UITheme.COLORS = {
	bg       = Color3.fromRGB(12, 13, 20),
	panel    = Color3.fromRGB(20, 22, 34),
	panel2   = Color3.fromRGB(30, 33, 50),
	accent   = Color3.fromRGB(150, 80, 255),   -- Omega-Lila
	accent2  = Color3.fromRGB(70, 200, 255),   -- Cyan
	gold     = Color3.fromRGB(255, 200, 45),
	red      = Color3.fromRGB(235, 65, 80),
	green    = Color3.fromRGB(80, 220, 120),
	text     = Color3.fromRGB(238, 240, 250),
	textDim  = Color3.fromRGB(145, 152, 175),
}

UITheme.FONTS = {
	header  = Enum.Font.GothamBold,
	body    = Enum.Font.Gotham,
	display = Enum.Font.GothamBlack,
}

UITheme.CORNER    = UDim.new(0, 8)
UITheme.CORNER_LG = UDim.new(0, 14)

function UITheme.applyCorner(instance, radiusOverride)
	local c = Instance.new("UICorner")
	c.CornerRadius = radiusOverride or UITheme.CORNER
	c.Parent = instance
end

function UITheme.applyStroke(instance, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(60, 65, 95)
	s.Thickness = thickness or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = instance
	return s
end

return UITheme
