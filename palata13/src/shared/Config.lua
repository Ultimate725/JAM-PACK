--[[
	ПАЛАТА 13 — ГЛАВНЫЙ КОНФИГ
	Этот файл лежит в ОБОИХ плейсах (Лобби и Больница). Меняй его одинаково в обоих!
	Все ID — просто числа. 0 = не настроено (игра не сломается, просто функция будет выключена).
]]

local Config = {}

Config.GameName = "ПАЛАТА 13"
Config.Version = "v1.0"

-- 1) ID ПЛЕЙСОВ ------------------------------------------------------------
-- Creator Hub -> твоя игра -> Places. Лобби = стартовый плейс, Больница = второй плейс.
Config.LobbyPlaceId = 0
Config.GamePlaceId = 0

Config.MaxPlayersPerRound = 4
Config.QueueCountdown = 20 -- секунд на вратах перед телепортом

-- 2) ЗВУКИ (загрузи .ogg из папки Sounds и вставь ID) -------------------
Config.Sounds = {
	FlashlightOn = 0,
	FlashlightOff = 0,
	MonsterStep = 0,
	MonsterBreath = 0,
	MonsterScream = 0,
	ChaseSting = 0,
	Ambience = 0,
	MenuMusic = 0,
	Heartbeat = 0,
	Static = 0,
	UIHover = 0,
	UIClick = 0,
	Pickup = 0,
	FuseInsert = 0,
	GeneratorOn = 0,
	Purchase = 0,
	Teleport = 0,
	Whisper = 0,
	LightBuzz = 0,
	MetalBang = 0,
}

-- 3) МАГАЗИН ЗА РОБУКСЫ ----------------------------------------------------
-- Game Pass (покупается 1 раз): Creator Hub -> Monetization -> Passes
Config.GamePasses = {
	PremiumPass = 0, -- Премиум-дорожка батлпасса
	VIP = 0, -- x2 монет за раунды + титул VIP
	BigBattery = 0, -- батарея фонарика садится в 2 раза медленнее + ярче луч
}

-- Developer Products (можно покупать много раз): Monetization -> Developer Products
Config.Products = {
	Coins100 = 0,
	Coins500 = 0,
	Coins1500 = 0,
	SkipTier = 0, -- +1 уровень батлпасса
	Revive = 0, -- возрождение в раунде (или +1 жетон, если куплено в лобби)
}

-- Как предметы выглядят в магазине (цена берётся из Roblox автоматически)
Config.ShopRobux = {
	{ kind = "pass", key = "PremiumPass", name = "ПРЕМИУМ БАТЛПАСС", desc = "Открывает красную дорожку наград: редкие фонарики, титулы и монеты.", icon = "🩸" },
	{ kind = "pass", key = "VIP", name = "VIP", desc = "x2 монет за каждый раунд и золотой титул VIP.", icon = "👑" },
	{ kind = "pass", key = "BigBattery", name = "ВЕЧНАЯ БАТАРЕЯ", desc = "Фонарик садится в 2 раза медленнее и светит дальше.", icon = "🔋" },
	{ kind = "product", key = "Coins100", name = "100 МОНЕТ", desc = "Горсть старых монет.", icon = "🪙" },
	{ kind = "product", key = "Coins500", name = "500 МОНЕТ", desc = "Кошелёк пропавшего врача.", icon = "💰" },
	{ kind = "product", key = "Coins1500", name = "1500 МОНЕТ", desc = "Сейф главврача.", icon = "🏦" },
	{ kind = "product", key = "SkipTier", name = "ПРОПУСК УРОВНЯ", desc = "+1 уровень батлпасса прямо сейчас.", icon = "⏭" },
	{ kind = "product", key = "Revive", name = "ЖЕТОН ВОЗРОЖДЕНИЯ", desc = "Вернись в раунд после смерти.", icon = "✚" },
}

Config.ProductRewards = {
	Coins100 = { coins = 100 },
	Coins500 = { coins = 500 },
	Coins1500 = { coins = 1500 },
	SkipTier = { tiers = 1 },
	Revive = { revive = 1 },
}

-- 4) ФОНАРИКИ (скины света) ----------------------------------------------------
-- price > 0 = продаётся за монеты; source = "bp" = только из батлпасса
Config.Flashlights = {
	{ id = "Standard", name = "Стандарт", color = Color3.fromRGB(255, 236, 205), price = 0 },
	{ id = "Cold", name = "Холодный", color = Color3.fromRGB(200, 225, 255), price = 250 },
	{ id = "Toxic", name = "Ядовитый", color = Color3.fromRGB(150, 255, 120), price = 600 },
	{ id = "Ghost", name = "Призрачный", color = Color3.fromRGB(140, 255, 245), price = 900 },
	{ id = "Gold", name = "Золотой", color = Color3.fromRGB(255, 200, 90), price = 1500 },
	{ id = "Moon", name = "Лунный", color = Color3.fromRGB(180, 190, 255), price = 0, source = "bp" },
	{ id = "Ember", name = "Тлеющий", color = Color3.fromRGB(255, 140, 60), price = 0, source = "bp" },
	{ id = "Blood", name = "Кровавый", color = Color3.fromRGB(255, 50, 50), price = 0, source = "bp" },
	{ id = "Void", name = "Пустота", color = Color3.fromRGB(170, 90, 255), price = 0, source = "bp" },
	{ id = "Aurora", name = "Северное сияние", color = Color3.fromRGB(90, 255, 200), price = 0, source = "bp" },
}

Config.Titles = {
	{ id = "Newbie", name = "Новенький пациент", color = Color3.fromRGB(190, 180, 170) },
	{ id = "Survivor", name = "Выживший", color = Color3.fromRGB(150, 220, 150) },
	{ id = "Nightwalker", name = "Ночной странник", color = Color3.fromRGB(150, 170, 255) },
	{ id = "Insomniac", name = "Бессонница", color = Color3.fromRGB(200, 160, 255) },
	{ id = "Ward13", name = "Жилец палаты 13", color = Color3.fromRGB(255, 120, 120) },
	{ id = "Butcher", name = "Мясник", color = Color3.fromRGB(200, 30, 30) },
	{ id = "Patient", name = "Пациент № 13", color = Color3.fromRGB(230, 230, 230) },
	{ id = "Nightmare", name = "Живой кошмар", color = Color3.fromRGB(255, 60, 60) },
	{ id = "Eye", name = "Глаз Пациента", color = Color3.fromRGB(255, 220, 80) },
	{ id = "VIP", name = "VIP", color = Color3.fromRGB(255, 205, 60) },
}

Config.ShowTitlesAboveHead = true -- только в лобби

-- 5) НАГРАДЫ ЗА РАУНД -----------------------------------------------------
Config.Rewards = {
	Escape = { coins = 100, xp = 150 },
	Death = { coins = 20, xp = 40 },
	Fuse = { coins = 15, xp = 25 },
	SurviveXPPer10s = 1,
}

-- 6) РАУНД ------------------------------------------------------------------
Config.Round = {
	Fuses = 5,
	Batteries = 16,
	TimeLimit = 900, -- 15 минут
	MonsterWakeDelay = 25,
	ReturnToLobbyDelay = 12,
	WaitForPlayers = 15,
}

Config.Monster = {
	PatrolSpeed = 9,
	InvestigateSpeed = 13,
	ChaseSpeed = 17,
	ChaseSpeedPerFuse = 0.5,
	EnragedBonus = 2.5,
	SightRange = 90,
	FlashlightSightRange = 125,
	HearSprintRange = 45,
	FOV = 150,
	KillRange = 5.5,
	LoseTargetTime = 6,
	HuntChance = 0.45, -- шанс что патруль пойдёт к случайному игроку
}

Config.Player = {
	WalkSpeed = 12,
	SprintSpeed = 20,
	StaminaMax = 100,
	StaminaDrain = 20,
	StaminaRegen = 13,
	BatteryDrainPerSec = 0.55,
}

-- хелперы ------------------------------------------------------------------
function Config.getFlashlight(id)
	for _, f in ipairs(Config.Flashlights) do
		if f.id == id then
			return f
		end
	end
	return Config.Flashlights[1]
end

function Config.getTitle(id)
	for _, t in ipairs(Config.Titles) do
		if t.id == id then
			return t
		end
	end
	return nil
end

function Config.productKeyById(productId)
	for key, id in pairs(Config.Products) do
		if id ~= 0 and id == productId then
			return key
		end
	end
	return nil
end

function Config.passKeyById(passId)
	for key, id in pairs(Config.GamePasses) do
		if id ~= 0 and id == passId then
			return key
		end
	end
	return nil
end

return Config
