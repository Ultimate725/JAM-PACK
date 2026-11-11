-- БАТЛПАСС: 30 уровней, бесплатная и премиум дорожки
local Config = require(script.Parent.Config)

local BP = {}
BP.SeasonName = "СЕЗОН 1: БЕССОННИЦА"
BP.XPPerTier = 120
BP.MaxTier = 30

local function coins(n)
	return { type = "coins", amount = n }
end
local function light(id)
	return { type = "flashlight", id = id }
end
local function title(id)
	return { type = "title", id = id }
end
local function revive(n)
	return { type = "revive", amount = n }
end

local free = {
	coins(50), coins(60), revive(1), coins(70), title("Survivor"),
	coins(80), coins(90), revive(1), coins(100), light("Moon"),
	coins(110), coins(120), title("Nightwalker"), coins(130), revive(1),
	coins(140), coins(150), coins(160), revive(1), light("Ember"),
	coins(170), coins(180), coins(190), revive(1), title("Insomniac"),
	coins(200), coins(210), coins(220), revive(1), title("Ward13"),
}

local premium = {
	coins(150), light("Blood"), coins(200), revive(2), title("Butcher"),
	coins(250), coins(250), revive(2), coins(300), light("Void"),
	coins(300), title("Patient"), coins(350), revive(2), coins(400),
	coins(400), revive(3), coins(450), coins(450), light("Aurora"),
	coins(500), revive(3), coins(500), coins(550), title("Nightmare"),
	coins(600), revive(3), coins(700), coins(800), title("Eye"),
}

BP.Tiers = {}
for i = 1, BP.MaxTier do
	BP.Tiers[i] = { free = free[i], premium = premium[i] }
end

function BP.tierFromXP(xp)
	return math.clamp(math.floor((xp or 0) / BP.XPPerTier), 0, BP.MaxTier)
end

function BP.progress(xp)
	local tier = BP.tierFromXP(xp)
	if tier >= BP.MaxTier then
		return tier, 1
	end
	return tier, ((xp or 0) % BP.XPPerTier) / BP.XPPerTier
end

function BP.describe(reward)
	if not reward then
		return "—"
	end
	if reward.type == "coins" then
		return reward.amount .. " монет"
	elseif reward.type == "revive" then
		return "Жетон возр. x" .. reward.amount
	elseif reward.type == "flashlight" then
		return "Фонарик: " .. Config.getFlashlight(reward.id).name
	elseif reward.type == "title" then
		local t = Config.getTitle(reward.id)
		return "Титул: " .. (t and t.name or reward.id)
	end
	return "?"
end

function BP.icon(reward)
	if not reward then
		return ""
	end
	if reward.type == "coins" then
		return "🪙"
	elseif reward.type == "revive" then
		return "✚"
	elseif reward.type == "flashlight" then
		return "🔦"
	elseif reward.type == "title" then
		return "🏷"
	end
	return "?"
end

return BP
