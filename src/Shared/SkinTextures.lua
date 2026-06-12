-- SkinTextures.lua — Prozedurale Skin-Texturen (CS-Style: Fade, Galaxie,
-- Flammen, Carbon …) via EditableImage. Läuft auf JEDEM Client lokal:
-- alle Clients generieren dieselbe Textur deterministisch → alle sehen
-- denselben Skin, ohne Asset-Uploads, ohne Moderation, ohne Permissions.
--
-- Voraussetzung: das echte AWP-Mesh-Template (MeshPart) — die Textur wird
-- über MeshPart.TextureContent gelegt. Ohne EditableImage-Support bleibt die
-- Original-Textur (pcall-Fallback).
local SkinTextures = {}

local AssetService = game:GetService("AssetService")

local SIZE = 256

-- ── Pixel-Helfer ──────────────────────────────────────────────────────────────
local function clamp01(x)
	return x < 0 and 0 or (x > 1 and 1 or x)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Mehrfach-Verlauf: stops = { {pos, {r,g,b}}, ... } (pos aufsteigend, 0..1)
local function gradientAt(stops, t)
	t = clamp01(t)
	for i = 1, #stops - 1 do
		local a, b = stops[i], stops[i + 1]
		if t <= b[1] then
			local f = (t - a[1]) / math.max(1e-4, b[1] - a[1])
			f = clamp01(f)
			return lerp(a[2][1], b[2][1], f), lerp(a[2][2], b[2][2], f), lerp(a[2][3], b[2][3], f)
		end
	end
	local last = stops[#stops][2]
	return last[1], last[2], last[3]
end

-- Deterministisches Hash-Rauschen (kein math.random → überall identisch)
local function hash2(x, y, seed)
	local n = math.sin(x * 127.1 + y * 311.7 + seed * 74.7) * 43758.5453
	return n - math.floor(n)
end

-- Weiches Value-Noise
local function noise2(x, y, seed)
	local xi, yi = math.floor(x), math.floor(y)
	local xf, yf = x - xi, y - yi
	local a = hash2(xi, yi, seed)
	local b = hash2(xi + 1, yi, seed)
	local c = hash2(xi, yi + 1, seed)
	local d = hash2(xi + 1, yi + 1, seed)
	local u = xf * xf * (3 - 2 * xf)
	local v = yf * yf * (3 - 2 * yf)
	return lerp(lerp(a, b, u), lerp(c, d, u), v)
end

-- ── Rezepte ───────────────────────────────────────────────────────────────────
-- Jedes Rezept: f(x, y) -> r, g, b  (x/y in 0..1)
-- Gestaltungssprache pro Tier: Commons ruhig/matt, Rares metallisch glänzend,
-- Legendary Pattern + Glow-Farben, Godly/Mythical spektakulär (Fade/Galaxie).
local C = function(r, g, b) return { r, g, b } end

local RECIPES = {
	-- ── Common: ruhige Material-Looks ──
	holz = function(x, y)
		local ring = noise2(x * 3, y * 22, 7) * 0.5 + noise2(x * 9, y * 60, 8) * 0.5
		local r, g, b = gradientAt({ {0, C(96, 62, 34)}, {0.5, C(140, 96, 55)}, {1, C(96, 62, 34)} }, ring)
		return r, g, b
	end,
	beton = function(x, y)
		local n = noise2(x * 18, y * 18, 12) * 0.6 + noise2(x * 60, y * 60, 13) * 0.4
		local v = 110 + n * 55
		return v, v, v - 6
	end,
	khaki = function(x, y)
		-- klassisches Flecken-Camo
		local n = noise2(x * 7, y * 7, 21)
		if n > 0.62 then return 86, 92, 58 end
		if n > 0.45 then return 122, 124, 86 end
		if n < 0.22 then return 70, 72, 48 end
		return 138, 138, 100
	end,
	schiefer = function(x, y)
		local n = noise2(x * 30, y * 6, 31) * 0.5 + noise2(x * 90, y * 14, 32) * 0.5
		local v = 64 + n * 38
		return v, v + 3, v + 12
	end,
	rost = function(x, y)
		local n = noise2(x * 12, y * 12, 41)
		local rust = noise2(x * 40, y * 40, 42)
		if rust > 0.72 then return 96 + n * 30, 56 + n * 16, 34 end
		return 132 + n * 36, 84 + n * 22, 52 + n * 12
	end,

	-- ── Rare: Metallic mit Sheen-Streifen ──
	chrom = function(x, y)
		local sheen = math.abs(math.sin((x + y) * 9))
		local v = 150 + sheen * 95 + noise2(x * 50, y * 50, 51) * 10
		return v, v + 3, v + 10
	end,
	gold = function(x, y)
		local sheen = math.abs(math.sin((x + y * 0.6) * 8))
		return 170 + sheen * 85, 130 + sheen * 70, 30 + sheen * 35
	end,
	rosegold = function(x, y)
		-- FADE: das ikonische Magenta→Orange→Gold (diagonal, wie AWP Fade)
		local t = clamp01(x * 0.7 + (1 - y) * 0.5)
		local r, g, b = gradientAt({
			{0, C(255, 60, 200)}, {0.45, C(255, 110, 80)}, {0.8, C(255, 200, 70)}, {1, C(255, 230, 120)},
		}, t)
		local sheen = math.abs(math.sin((x + y) * 11)) * 18
		return r + sheen, g + sheen * 0.6, b
	end,
	saphir = function(x, y)
		local sheen = math.abs(math.sin((x * 1.3 + y) * 7))
		local n = noise2(x * 24, y * 24, 61) * 20
		return 30 + sheen * 60, 70 + sheen * 80 + n * 0.4, 160 + sheen * 90
	end,
	smaragd = function(x, y)
		local sheen = math.abs(math.sin((x + y * 1.4) * 7))
		return 24 + sheen * 50, 130 + sheen * 90, 70 + sheen * 55
	end,

	-- ── Legendary: dunkle Basis + leuchtende Patterns ──
	viper = function(x, y)
		-- Schlangenhaut-Hex-Pattern in Giftgrün
		local hx = math.abs(math.sin(x * 42) * math.sin(y * 36 + x * 8))
		local base = 22 + noise2(x * 30, y * 30, 71) * 16
		if hx > 0.82 then return 70, 235, 60 end
		return base, base + 8, base
	end,
	plasma = function(x, y)
		local streak = math.abs(math.sin(y * 24 + math.sin(x * 12) * 2.2))
		local r, g, b = gradientAt({ {0, C(28, 16, 30)}, {0.75, C(120, 30, 110)}, {1, C(255, 70, 200)} }, streak)
		return r, g, b
	end,
	blaufeuer = function(x, y)
		-- blaue Flammen von unten
		local flame = clamp01((1 - y) + (noise2(x * 14, y * 9, 81) - 0.5) * 0.9)
		return gradientAt({ {0, C(14, 16, 30)}, {0.5, C(25, 60, 140)}, {0.8, C(70, 170, 255)}, {1, C(200, 240, 255)} }, flame)
	end,
	solar = function(x, y)
		local flame = clamp01((1 - y) * 1.15 + (noise2(x * 12, y * 10, 91) - 0.5) * 0.8)
		return gradientAt({ {0, C(30, 16, 10)}, {0.45, C(160, 50, 15)}, {0.75, C(255, 140, 30)}, {1, C(255, 230, 120)} }, flame)
	end,
	toxin = function(x, y)
		-- Säure-Drips von oben
		local drip = noise2(x * 22, 0, 101)
		local edge = 0.25 + drip * 0.5 + noise2(x * 60, y * 4, 102) * 0.08
		if y < edge then
			local glow = noise2(x * 40, y * 40, 103) * 40
			return 140 + glow, 230, 30 + glow
		end
		local base = 24 + noise2(x * 26, y * 26, 104) * 14
		return base, base + 9, base
	end,

	-- ── Godly: die Showstopper ──
	galaxie = function(x, y)
		local neb = noise2(x * 5, y * 5, 111) * 0.6 + noise2(x * 13, y * 13, 112) * 0.4
		local r, g, b = gradientAt({
			{0, C(12, 6, 30)}, {0.5, C(45, 18, 90)}, {0.78, C(110, 50, 180)}, {1, C(70, 160, 230)},
		}, neb)
		local star = hash2(math.floor(x * 220), math.floor(y * 220), 113)
		if star > 0.992 then
			local s = (star - 0.992) / 0.008
			return lerp(r, 255, s), lerp(g, 255, s), lerp(b, 255, s)
		end
		return r, g, b
	end,
	drachen = function(x, y)
		-- glühende Drachenschuppen
		local sx, sy = x * 16, y * 12
		local cell = math.abs(math.sin(sx) * math.sin(sy + math.sin(sx * 0.5)))
		local ember = noise2(x * 8, y * 8, 121)
		if cell > 0.78 then
			return 255, 90 + ember * 70, 25
		end
		local base = 30 + ember * 22
		return base + 14, base * 0.5, base * 0.45
	end,
	frost = function(x, y)
		local crack = math.abs(math.sin(x * 26 + math.sin(y * 18) * 3))
		local ice = noise2(x * 10, y * 10, 131)
		local r, g, b = gradientAt({ {0, C(18, 40, 60)}, {0.6, C(60, 130, 180)}, {1, C(170, 235, 255)} }, ice)
		if crack > 0.93 then return 220, 250, 255 end
		return r, g, b
	end,
	neondrache = function(x, y)
		-- Gold-Schuppen mit Cyan-Runen-Streifen ("GEBOREN IM PLASMAFEUER")
		local scale = math.abs(math.sin(x * 22) * math.sin(y * 16))
		local stripe = math.abs(math.sin((x * 0.4 + y) * 18))
		if stripe > 0.92 then return 60, 230, 255 end
		local sheen = scale * 60
		return 185 + sheen * 0.8, 140 + sheen * 0.6, 55 + sheen * 0.3
	end,
	primeaegis = function(x, y)
		local sheen = math.abs(math.sin((x + y) * 7))
		local stripe = math.abs(math.sin(y * 26))
		if stripe > 0.94 then return 255, 200, 70 end
		local v = 220 + sheen * 30
		return v, v, v + 6
	end,

	-- ── Mythical ──
	singularitaet = function(x, y)
		-- schwarzes Loch: dunkler Kern, Licht-Akkretionsring
		local dx, dy = x - 0.5, y - 0.5
		local d = math.sqrt(dx * dx + dy * dy)
		local ring = math.exp(-((d - 0.3) ^ 2) * 220)
		local star = hash2(math.floor(x * 240), math.floor(y * 240), 141)
		local base = 6 + noise2(x * 6, y * 6, 142) * 10
		local r = base + ring * 240
		local g = base + ring * 235
		local b = base + 6 + ring * 255
		if star > 0.994 and ring < 0.2 then
			return 235, 235, 255
		end
		return r, g, b
	end,
	voidaura = function(x, y)
		local neb = noise2(x * 7, y * 7, 151) * 0.55 + noise2(x * 19, y * 19, 152) * 0.45
		local r, g, b = gradientAt({
			{0, C(8, 4, 16)}, {0.55, C(40, 12, 70)}, {0.85, C(120, 40, 200)}, {1, C(200, 120, 255)},
		}, neb)
		local crack = math.abs(math.sin(x * 30 + math.sin(y * 22) * 4))
		if crack > 0.965 then return 190, 90, 255 end
		return r, g, b
	end,
}

-- ── Generierung + Cache ───────────────────────────────────────────────────────
local cache = {}   -- [skinId] = Content | false (= nicht verfügbar/kein Rezept)

local function generate(skinId)
	local recipe = RECIPES[skinId]
	if not recipe then return false end   -- z.B. "standard" → Original-Textur

	local ok, content = pcall(function()
		local ei = AssetService:CreateEditableImage({ Size = Vector2.new(SIZE, SIZE) })
		local buf = buffer.create(SIZE * SIZE * 4)
		for py = 0, SIZE - 1 do
			local fy = py / (SIZE - 1)
			local rowBase = py * SIZE * 4
			for px = 0, SIZE - 1 do
				local r, g, b = recipe(px / (SIZE - 1), fy)
				local o = rowBase + px * 4
				buffer.writeu8(buf, o, math.clamp(math.floor(r + 0.5), 0, 255))
				buffer.writeu8(buf, o + 1, math.clamp(math.floor(g + 0.5), 0, 255))
				buffer.writeu8(buf, o + 2, math.clamp(math.floor(b + 0.5), 0, 255))
				buffer.writeu8(buf, o + 3, 255)
			end
		end
		ei:WritePixelsBuffer(Vector2.zero, Vector2.new(SIZE, SIZE), buf)
		return Content.fromObject(ei)
	end)
	return ok and content or false
end

-- Content für einen Skin (nil = Original-Textur behalten)
function SkinTextures.get(skinId)
	if cache[skinId] == nil then
		cache[skinId] = generate(skinId)
	end
	return cache[skinId] or nil
end

return SkinTextures
