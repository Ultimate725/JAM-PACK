--[[
	ПАЛАТА 13 — ГЛАВНЫЙ КОНФИГ
	Этот файл лежит в ОБОИХ плейсах (Лобби и Больница). Меняй его одинаково в обоих!
	Все ID — просто числа. 0 = не настроено (игра не сломается, просто функция будет выключена).
]]

local Config = {}

Config.GameName = "ПАЛАТА 13"
Config.Version = "v2.0"

-- 1) ID ПЛЕЙСОВ ------------------------------------------------------------
-- Creator Hub -> твоя игра -> Places. Лобби = стартовый плейс, Больница = второй плейс.
-- Все карты живут в ОДНОМ игровом плейсе (ServerStorage.Maps), карта выбирается у врат в лобби.
Config.LobbyPlaceId = 0
Config.GamePlaceId = 0

Config.MaxPlayersPerRound = 4 -- максимум, который можно выбрать у врат
Config.QueueCountdown = 20 -- секунд на вратах перед телепортом

-- 2) ЗВУКИ (загрузи .ogg из папки Sounds и вставь ID) -------------------
Config.Sounds = {
	FlashlightOn = 0,
	FlashlightOff = 0,
	MonsterStep = 0,
	MonsterBreath = 0,
	MonsterScream = 0,
	MonsterSniff = 0, -- принюхивается / прислушивается (слепой режим)
	Sonar = 0, -- "эхо-крик" в режиме КОШМАР
	ChaseSting = 0,
	Ambience = 0,
	AmbienceMorgue = 0,
	AmbienceForest = 0,
	MenuMusic = 0,
	Heartbeat = 0,
	Static = 0,
	UIHover = 0,
	UIClick = 0,
	Pickup = 0,
	FuseInsert = 0,
	GeneratorOn = 0,
	GeneratorCrank = 0, -- звук починки (loop)
	GateOpen = 0,
	Purchase = 0,
	Teleport = 0,
	Whisper = 0,
	LightBuzz = 0,
	MetalBang = 0,
	Breathing = 0, -- дыхание игрока в присяде
	Cloth = 0, -- шорох при присяде
	Drip = 0,
	Wind = 0,
	Crow = 0,
	Bell = 0,
	FootstepConcrete = 0, -- шаги игрока (с эхом)
	FootstepWood = 0,
	FootstepGrass = 0,
	FootstepMetal = 0,
	Paper = 0, -- записка
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
	{ id = "Patient", name = "Пациент № 13", color = Color3.fromRGB(230, 230, 230) },
	{ id = "Nightmare", name = "Живой кошмар", color = Color3.fromRGB(255, 60, 60) },
	{ id = "Eye", name = "Глаз Пациента", color = Color3.fromRGB(255, 220, 80) },
	{ id = "VIP", name = "VIP", color = Color3.fromRGB(255, 205, 60) },
	{ id = "Morgue", name = "Санитар морга", color = Color3.fromRGB(150, 200, 220), source = "map:Morgue" },
	{ id = "Forest", name = "Лесной призрак", color = Color3.fromRGB(120, 200, 140), source = "map:Sanatorium" },
	{ id = "Unkillable", name = "Неубиваемый", color = Color3.fromRGB(255, 255, 255), source = "nightmare" },
}

Config.ShowTitlesAboveHead = true -- только в лобби

-- 5) ПЕРКИ (покупаются за монеты в АПТЕКЕ в лобби, действуют всегда) ----------
Config.Perks = {
	{ id = "Slippers", name = "ТИХИЕ ТАПКИ", icon = "🩴", price = 350, desc = "Шаги на 30% тише. Оно слышит тебя хуже.", stat = "noise", value = 0.7 },
	{ id = "Lungs", name = "ВТОРОЕ ДЫХАНИЕ", icon = "🫁", price = 450, desc = "+30% выносливости и быстрее восстановление.", stat = "stamina", value = 1.3 },
	{ id = "Wrench", name = "ГАЕЧНЫЙ КЛЮЧ", icon = "🔧", price = 500, desc = "Генераторы чинятся на 25% быстрее.", stat = "repair", value = 1.25 },
	{ id = "Charm", name = "АМУЛЕТ МЕДСЕСТРЫ", icon = "🧿", price = 650, desc = "Оно теряет твой след на 35% быстрее.", stat = "lose", value = 0.65 },
	{ id = "Adrenaline", name = "АДРЕНАЛИН", icon = "💉", price = 700, desc = "+10% к скорости бега, когда Оно гонится за тобой.", stat = "sprint", value = 1.1 },
	{ id = "Battery", name = "ЗАПАСНАЯ БАТАРЕЯ", icon = "🔋", price = 400, desc = "Начинаешь раунд с 2 батарейками в кармане.", stat = "battery", value = 2 },
	{ id = "Nerves", name = "СТАЛЬНЫЕ НЕРВЫ", icon = "🫀", price = 550, desc = "Фонарик не мигает рядом с Ним.", stat = "nerves", value = 1 },
	{ id = "Revive", name = "ЖЕТОН ВОЗРОЖДЕНИЯ", icon = "✚", price = 900, desc = "Одноразовое возрождение. Можно купить много раз.", consumable = true },
}

-- 6) НАГРАДЫ ЗА РАУНД -----------------------------------------------------
Config.Rewards = {
	Escape = { coins = 100, xp = 150 },
	Death = { coins = 20, xp = 40 },
	Fuse = { coins = 15, xp = 25 },
	Generator = { coins = 30, xp = 40 },
	Note = { coins = 5, xp = 10 },
	SurviveXPPer10s = 1,
}

-- 7) КАРТЫ -----------------------------------------------------------------
-- id = имя папки в ServerStorage.Maps игрового плейса
Config.Maps = {
	{
		id = "Hospital",
		name = "ПАЛАТА 13",
		subtitle = "Психиатрическая больница № 13",
		icon = "🏥",
		story = "1987 год. Ночная смена. Пациента из 13-й палаты пытались «вылечить» током, пока не отключили свет во всём корпусе. С тех пор он ходит по коридорам и ищет врачей. Ты — врач.",
		goal = "Найди предохранители, почини генераторы в крыльях, включи свет и выбеги через ворота во дворе.",
		generators = 4,
		ambience = "Ambience",
		lighting = { fog = 400, density = 0.38, tint = Color3.fromRGB(228, 234, 242), ambient = Color3.fromRGB(12, 11, 13) },
		color = Color3.fromRGB(220, 60, 60),
	},
	{
		id = "Morgue",
		name = "МОРГ",
		subtitle = "Подвал. Холодильные камеры. Крематорий.",
		icon = "🧊",
		story = "Тело Пациента № 13 так и не сожгли: санитары морга пропали в ту же ночь. В подвале нет окон, вентиляция забита, а в ящиках холодильника кто-то стучит изнутри. Лифт обесточен.",
		goal = "Запусти генераторы котельной и крематория, чтобы подать ток на служебный лифт — это единственный выход.",
		generators = 4,
		ambience = "AmbienceMorgue",
		lighting = { fog = 150, density = 0.55, tint = Color3.fromRGB(190, 215, 230), ambient = Color3.fromRGB(8, 10, 13) },
		color = Color3.fromRGB(110, 190, 230),
	},
	{
		id = "Sanatorium",
		name = "САНАТОРИЙ «СОСНЫ»",
		subtitle = "Заброшенный лесной санаторий",
		icon = "🌲",
		story = "Детский корпус санатория закрыли после «несчастного случая». В лесу между корпусами, часовней и котельной по ночам слышат колокол. Ворота заперты, забор под напряжением… когда есть ток.",
		goal = "Пробейся через туман к корпусам, запусти генераторы и открой главные ворота. Не беги по сухим листьям.",
		generators = 4,
		ambience = "AmbienceForest",
		lighting = { fog = 120, density = 0.62, tint = Color3.fromRGB(200, 215, 205), ambient = Color3.fromRGB(10, 13, 11) },
		color = Color3.fromRGB(110, 200, 130),
	},
}

-- 8) СЛОЖНОСТЬ --------------------------------------------------------------
-- blind = Оно не видит, только слышит. Слух: радиусы в стадах для присядки / шага / бега.
Config.Difficulties = {
	{
		id = "Easy",
		name = "ЛЕГКО",
		icon = "🕯",
		desc = "Оно слепое, но слышит. Медленное. Хватит 2 генераторов. Для первого визита.",
		color = Color3.fromRGB(120, 200, 120),
		blind = true,
		hear = { crouch = 6, walk = 18, sprint = 48, flashlight = 0, interact = 25 },
		sight = 0,
		flashlightSight = 0,
		fov = 150,
		speed = { patrol = 8, investigate = 11, chase = 14.5 },
		loseTime = 4,
		wakeDelay = 40,
		generators = 2,
		timeLimit = 1080,
		sonar = 0,
		sense = 4,
		repair = 32, -- секунд починки генератора одним игроком
		xpMult = 0.8,
		coinMult = 0.8,
	},
	{
		id = "Medium",
		name = "СРЕДНЕ",
		icon = "🔦",
		desc = "Оно видит и слышит бег. Классическая Палата 13. 3 генератора.",
		color = Color3.fromRGB(235, 185, 70),
		blind = false,
		hear = { crouch = 0, walk = 10, sprint = 45, flashlight = 0, interact = 20 },
		sight = 90,
		flashlightSight = 125,
		fov = 150,
		speed = { patrol = 9, investigate = 13, chase = 17 },
		loseTime = 6,
		wakeDelay = 25,
		generators = 3,
		timeLimit = 900,
		sonar = 0,
		sense = 5,
		repair = 40,
		xpMult = 1,
		coinMult = 1,
	},
	{
		id = "Hard",
		name = "СЛОЖНО",
		icon = "🩸",
		desc = "Видит далеко, слышит шаги и щелчок фонарика. Быстрое и злопамятное. 3 генератора.",
		color = Color3.fromRGB(235, 70, 70),
		blind = false,
		hear = { crouch = 8, walk = 28, sprint = 80, flashlight = 45, interact = 60 },
		sight = 120,
		flashlightSight = 170,
		fov = 190,
		speed = { patrol = 10, investigate = 14.5, chase = 18.5 },
		loseTime = 9,
		wakeDelay = 15,
		generators = 3,
		timeLimit = 840,
		sonar = 0,
		sense = 7,
		repair = 48,
		xpMult = 1.4,
		coinMult = 1.4,
	},
	{
		id = "Nightmare",
		name = "КОШМАР",
		icon = "💀",
		desc = "Слепое — и поэтому слышит ВСЁ: шаги, присядку, фонарик, щелчки. Каждые полминуты кричит, и эхо выдаёт всех, кто шевелится. 4 генератора. Очень быстрое.",
		color = Color3.fromRGB(190, 60, 255),
		blind = true,
		hear = { crouch = 14, walk = 55, sprint = 140, flashlight = 70, interact = 110 },
		sight = 0,
		flashlightSight = 0,
		fov = 360,
		speed = { patrol = 11, investigate = 16, chase = 20 },
		loseTime = 12,
		wakeDelay = 10,
		generators = 4,
		timeLimit = 780,
		sonar = 30, -- секунд между эхо-криками (0 = нет)
		sense = 9,
		repair = 55,
		xpMult = 2,
		coinMult = 2,
	},
}

-- 9) РАУНД ------------------------------------------------------------------
Config.Round = {
	Fuses = 5, -- запасной параметр (реально = генераторов + 1)
	Batteries = 16,
	TimeLimit = 900,
	MonsterWakeDelay = 25,
	ReturnToLobbyDelay = 12,
	WaitForPlayers = 15,
	RepairTime = 40, -- секунд починки одного генератора одним игроком (на сложности см. repair)
	MaxFuses = 2, -- сколько предохранителей помещается в инвентарь
	IntroTime = 9, -- показ сюжета карты
}

Config.Monster = {
	PatrolSpeed = 9,
	InvestigateSpeed = 13,
	ChaseSpeed = 17,
	ChaseSpeedPerGenerator = 0.6,
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
	CrouchSpeed = 6.5,
	StaminaMax = 100,
	StaminaDrain = 20,
	StaminaRegen = 13,
	BatteryDrainPerSec = 0.55,
	-- шум игрока (множитель к радиусу слуха монстра)
	Noise = { crouch = 1, walk = 1, sprint = 1 },
}

-- хелперы ------------------------------------------------------------------
-- 10) ИНВЕНТАРЬ (нижняя панель). Батарейки сюда не попадают — они сразу идут в фонарик.
Config.Items = {
	{ id = "Fuses", name = "ПРЕДОХРАНИТЕЛЬ", icon = "⚡", color = Color3.fromRGB(255, 190, 60), desc = "Вставь в генератор (E). Носить можно не больше 2." },
	{ id = "Notes", name = "ЗАПИСКИ", icon = "📜", color = Color3.fromRGB(214, 204, 178), desc = "Обрывки истории этого места. Нажми, чтобы прочитать." },
}
Config.InventorySlots = 4

-- 11) ЗАПИСКИ — сюжет каждой карты (лежат на полу, E — взять)
Config.Notes = {
	Hospital = {
		"12 окт. 1987. Пациента из 13-й перевели на «интенсивную терапию». Главврач велел не записывать дозы. Я записываю.",
		"Третий сеанс тока. Он перестал кричать и начал смотреть. Не на нас — сквозь стены. Медсестра Л. говорит, что он слышит, как мы дышим.",
		"Свет отключили в 3:13. Генераторы в крыльях не запускаются сами — кто-то вынул предохранители. Ворота во двор на электрозамке.",
		"Если ты это читаешь — не свети ему в лицо. Он идёт на свет. И не беги. Бег он слышит через три этажа.",
		"Я заперся в шкафчике. Он прошёл мимо. Потом вернулся. Он всегда возвращается, если видел, куда ты спрятался.",
	},
	Morgue = {
		"Журнал санитара. Тело №13 поступило без бирки. Тёплое. Через шесть часов — всё ещё тёплое. Кремацию назначили на утро.",
		"Ночью из холодильника стучали. Ящик 13. Открыл — пусто, внутри царапины. Свежие. С ИЗНАНКИ двери.",
		"Печь не разжигать! Петров разжёг. Петрова больше нет. В пепле нашли его часы и кусок больничной рубашки. Не его.",
		"Грузовой лифт — единственный выход, лестница завалена. Лифт на отдельном питании: котельная, прачечная, мастерская, насосная.",
		"Оно не видит в темноте подвала. Оно слушает. Если оно остановилось и наклонило голову — замри. Не дыши.",
	},
	Sanatorium = {
		"Санаторий «Сосны», детский корпус. Отчёт: после процедур дети спят лучше. Все, кроме Миши из 13-й. Миша рисует высокого человека.",
		"Миша говорит, что высокий человек живёт в котельной и просит открыть дверь. Котельную закрыли на ключ. Ключ пропал.",
		"Колокол в часовне звонил в 3:13. Звонаря у нас нет с 1979 года. Утром на полу часовни — мокрые следы босых ног. Большие.",
		"Забор под напряжением, ворота открываются только от генераторов. Без тока отсюда не выйти. Я спрятал предохранители по корпусам.",
		"Не бегите по листьям. Оно слышит. Дети знали это. Дети никогда не бегали. Поэтому их так долго не могли найти.",
	},
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

function Config.getMap(id)
	for _, m in ipairs(Config.Maps) do
		if m.id == id then
			return m
		end
	end
	return Config.Maps[1]
end

function Config.getDifficulty(id)
	for _, d in ipairs(Config.Difficulties) do
		if d.id == id then
			return d
		end
	end
	return Config.Difficulties[2]
end

function Config.getPerk(id)
	for _, p in ipairs(Config.Perks) do
		if p.id == id then
			return p
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
