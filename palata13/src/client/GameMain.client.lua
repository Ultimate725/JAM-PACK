--[[
	ПАЛАТА 13 — клиент раунда: HUD, бег, ПРИСЯДКА, покачивание камеры, свет, звуки,
	скример, наблюдение, интро карты, настройки (громкость), эхо-крик Кошмара.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sound = require(Shared:WaitForChild("Sound"))
local UI = require(Shared:WaitForChild("UI"))
local ClientData = require(Shared:WaitForChild("ClientData"))
local Animator = require(Shared:WaitForChild("MonsterAnimator"))
local FL = require(Shared:WaitForChild("FlashlightClient"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local P = Config.Player
local Colors = UI.Colors

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

ClientData.start()
Animator.start()
local fl = FL.start()

-- НАСТРОЙКИ -------------------------------------------------------------------
local settings = { master = 1, music = 0.6, sfx = 1, sensitivity = 1, crouchToggle = true }
local function applySettings()
	Sound.setVolumes(settings.master, settings.music, settings.sfx)
	UserInputService.MouseDeltaSensitivity = settings.sensitivity
end
local function loadSettings(d)
	if d and d.settings then
		for k, v in pairs(d.settings) do
			settings[k] = v
		end
	end
	applySettings()
end
loadSettings(ClientData.get())
ClientData.Changed:Connect(loadSettings)
local saveToken = 0
local function saveSettings()
	saveToken += 1
	local my = saveToken
	task.delay(0.8, function()
		if my == saveToken then
			Remotes.Settings:FireServer(settings)
		end
	end)
end

-- GUI -----------------------------------------------------------------------
local gui = UI.new("ScreenGui", {
	Name = "HUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
	Parent = player:WaitForChild("PlayerGui"),
})
UI.vignette(gui, 0.6)

local function bar(name, yOffset, color, text)
	local holder = UI.new("Frame", {
		Name = name,
		Size = UDim2.fromOffset(240, 32),
		Position = UDim2.new(0, 24, 1, yOffset),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = gui,
	})
	local lbl = UI.label({
		Text = text,
		Font = UI.FontMono,
		TextSize = 13,
		TextColor3 = Colors.Dim,
		Size = UDim2.new(1, 0, 0, 14),
		ZIndex = 5,
		Parent = holder,
	})
	local back = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 9),
		Position = UDim2.fromOffset(0, 19),
		BackgroundColor3 = Color3.fromRGB(18, 10, 10),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = holder,
	}, { UI.stroke(Colors.Red, 1, 0.6) })
	local fill = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = back,
	})
	return holder, fill, lbl
end

local batteryHolder, batteryFill, batteryLabel = bar("Battery", -64, Color3.fromRGB(230, 220, 160), "ФОНАРИК 100%")
local staminaHolder, staminaFill, staminaLabel = bar("Stamina", -24, Color3.fromRGB(170, 40, 40), "ДЫХАНИЕ")
local noiseHolder, noiseFill, noiseLabel = bar("Noise", -104, Color3.fromRGB(200, 120, 40), "ШУМ")

local mapLabel = UI.label({
	Text = "",
	Font = UI.FontTitle,
	TextSize = 18,
	TextColor3 = Colors.Dim,
	Size = UDim2.fromOffset(420, 22),
	Position = UDim2.fromOffset(24, 18),
	TextStrokeTransparency = 0.6,
	ZIndex = 5,
	Parent = gui,
})
local diffLabel = UI.label({
	Text = "",
	Font = UI.FontMono,
	TextSize = 13,
	TextColor3 = Colors.Dim,
	Size = UDim2.fromOffset(420, 16),
	Position = UDim2.fromOffset(24, 42),
	ZIndex = 5,
	Parent = gui,
})

local objective = UI.label({
	Text = "ГЕНЕРАТОРЫ  0/3",
	Font = UI.FontTitle,
	TextSize = 22,
	TextColor3 = Colors.Text,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromOffset(520, 28),
	Position = UDim2.new(0.5, 0, 0, 18),
	AnchorPoint = Vector2.new(0.5, 0),
	TextStrokeTransparency = 0.5,
	ZIndex = 5,
	Parent = gui,
})
local timerLabel = UI.label({
	Text = "15:00",
	Font = UI.FontMono,
	TextSize = 15,
	TextColor3 = Colors.Dim,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromOffset(200, 18),
	Position = UDim2.new(0.5, 0, 0, 48),
	AnchorPoint = Vector2.new(0.5, 0),
	ZIndex = 5,
	Parent = gui,
})
local carryLabel = UI.label({
	Text = "⚡ У ТЕБЯ ПРЕДОХРАНИТЕЛЬ — ВСТАВЬ ЕГО В ГЕНЕРАТОР",
	Font = UI.FontBold,
	TextSize = 16,
	TextColor3 = Colors.Gold,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromOffset(560, 22),
	Position = UDim2.new(0.5, 0, 0, 72),
	AnchorPoint = Vector2.new(0.5, 0),
	TextStrokeTransparency = 0.4,
	Visible = false,
	ZIndex = 5,
	Parent = gui,
})
local hint = UI.label({
	Text = UserInputService.TouchEnabled and "кнопки справа: свет / бег / присесть" or "F — фонарик   ·   SHIFT — бег   ·   C — присесть   ·   E — взаимодействие   ·   M — настройки",
	Font = UI.FontMono,
	TextSize = 13,
	TextColor3 = Colors.Dim,
	TextTransparency = 0.3,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromOffset(760, 18),
	Position = UDim2.new(0.5, 0, 1, -18),
	AnchorPoint = Vector2.new(0.5, 1),
	ZIndex = 5,
	Parent = gui,
})
task.delay(50, function()
	UI.tween(hint, 2, { TextTransparency = 1 })
end)

-- прогресс починки генератора
local repairHolder = UI.new("Frame", {
	Size = UDim2.fromOffset(360, 44),
	Position = UDim2.new(0.5, 0, 0.62, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 7,
	Parent = gui,
})
UI.label({
	Text = "ЧИНИШЬ ГЕНЕРАТОР — ЭТО ШУМНО",
	Font = UI.FontMono,
	TextSize = 14,
	TextColor3 = Colors.Gold,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 18),
	ZIndex = 7,
	Parent = repairHolder,
})
local repairBack = UI.new("Frame", {
	Size = UDim2.new(1, 0, 0, 12),
	Position = UDim2.fromOffset(0, 24),
	BackgroundColor3 = Color3.fromRGB(18, 10, 10),
	BorderSizePixel = 0,
	ZIndex = 7,
	Parent = repairHolder,
}, { UI.stroke(Colors.Gold, 1, 0.4) })
local repairFill = UI.new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Colors.Gold,
	BorderSizePixel = 0,
	ZIndex = 8,
	Parent = repairBack,
})

local msg = UI.label({
	Text = "",
	Font = UI.FontTitle,
	TextSize = 30,
	TextColor3 = Colors.Text,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, -80, 0, 90),
	Position = UDim2.fromScale(0.5, 0.24),
	AnchorPoint = Vector2.new(0.5, 0.5),
	TextTransparency = 1,
	TextStrokeTransparency = 0.3,
	ZIndex = 10,
	Parent = gui,
})
local msgToken = 0
local function showMessage(text, color, duration)
	msgToken += 1
	local my = msgToken
	msg.Text = text
	msg.TextColor3 = color or Colors.Text
	msg.TextTransparency = 1
	UI.tween(msg, 0.25, { TextTransparency = 0 })
	task.spawn(function()
		for _ = 1, 6 do
			if my ~= msgToken then
				return
			end
			msg.TextTransparency = math.random() < 0.5 and 0.55 or 0
			msg.Position = UDim2.new(0.5, math.random(-4, 4), 0.24, math.random(-2, 2))
			task.wait(0.04)
		end
		msg.TextTransparency = 0
		msg.Position = UDim2.fromScale(0.5, 0.24)
	end)
	task.delay(duration or 4.5, function()
		if my == msgToken then
			UI.tween(msg, 0.9, { TextTransparency = 1 })
		end
	end)
end

-- оверлей шкафчика: смотрим сквозь щели
local lockerOverlay = UI.new("Frame", {
	Name = "Locker",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 8,
	Parent = gui,
})
for i = 0, 13 do
	UI.new("Frame", {
		Size = UDim2.new(1, 0, 1 / 14, -5),
		Position = UDim2.fromScale(0, i / 14),
		BackgroundColor3 = Color3.fromRGB(6, 6, 7),
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = lockerOverlay,
	})
end
UI.label({
	Text = "ТЫ В УКРЫТИИ. НЕ ДЫШИ.   [E] — выйти",
	Font = UI.FontMono,
	TextSize = 14,
	TextColor3 = Colors.Dim,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 20),
	Position = UDim2.new(0, 0, 1, -60),
	ZIndex = 9,
	Parent = lockerOverlay,
})

local flash = UI.new("Frame", {
	Name = "Flash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 90,
	Parent = gui,
})
local fade = UI.new("Frame", {
	Name = "Fade",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	ZIndex = 95,
	Parent = gui,
})
local fadeText = UI.label({
	Text = "",
	Font = UI.FontTitle,
	TextSize = 64,
	TextColor3 = Colors.BrightRed,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 96,
	Parent = fade,
})
task.delay(1, function()
	UI.tween(fade, 2.5, { BackgroundTransparency = 1 })
end)

Remotes.Notify.OnClientEvent:Connect(function(text, color)
	UI.toast(gui, text, color)
end)

-- ИНТРО КАРТЫ -----------------------------------------------------------------
local intro = UI.new("Frame", {
	Name = "Intro",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(3, 2, 2),
	BackgroundTransparency = 0.08,
	Visible = false,
	ZIndex = 70,
	Parent = gui,
})
local introIcon = UI.label({ Text = "", TextSize = 64, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromScale(0, 0.1), ZIndex = 71, Parent = intro })
local introTitle = UI.label({ Text = "", Font = UI.FontTitle, TextSize = 64, TextColor3 = Colors.BrightRed, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromScale(0, 0.2), ZIndex = 71, Parent = intro })
local introSub = UI.label({ Text = "", Font = UI.FontMono, TextSize = 18, TextColor3 = Colors.Dim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromScale(0, 0.31), ZIndex = 71, Parent = intro })
local introStory = UI.label({ Text = "", TextSize = 21, TextColor3 = Colors.Text, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(0.6, 0, 0, 150), Position = UDim2.new(0.2, 0, 0.4, 0), ZIndex = 71, Parent = intro })
local introGoal = UI.label({ Text = "", Font = UI.FontBold, TextSize = 19, TextColor3 = Colors.Gold, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(0.6, 0, 0, 70), Position = UDim2.new(0.2, 0, 0.62, 0), ZIndex = 71, Parent = intro })
local introDiff = UI.label({ Text = "", Font = UI.FontTitle, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromScale(0, 0.76), ZIndex = 71, Parent = intro })
local introDiffDesc = UI.label({ Text = "", Font = UI.FontMono, TextSize = 15, TextColor3 = Colors.Dim, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(0.7, 0, 0, 50), Position = UDim2.new(0.15, 0, 0.81, 0), ZIndex = 71, Parent = intro })
local introWait = UI.label({ Text = "", Font = UI.FontMono, TextSize = 16, TextColor3 = Colors.Dim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -40), ZIndex = 71, Parent = intro })

local function typewrite(label, text)
	task.spawn(function()
		local len = utf8.len(text) or #text
		for n = 1, len, 2 do
			if label.Text ~= nil and intro.Visible == false then
				return
			end
			local cut = utf8.offset(text, n + 1)
			label.Text = cut and string.sub(text, 1, cut - 1) or text
			task.wait(0.02)
		end
		label.Text = text
	end)
end

local function showIntro(mapId, diffId)
	local m = Config.getMap(mapId)
	local d = Config.getDifficulty(diffId)
	introIcon.Text = m.icon or ""
	introTitle.Text = m.name
	introTitle.TextColor3 = m.color or Colors.BrightRed
	introSub.Text = m.subtitle or ""
	introStory.Text = ""
	introGoal.Text = ""
	introDiff.Text = (d.icon or "") .. "  СЛОЖНОСТЬ: " .. d.name
	introDiff.TextColor3 = d.color or Colors.Text
	introDiffDesc.Text = d.desc
	intro.Visible = true
	intro.BackgroundTransparency = 1
	UI.tween(intro, 0.6, { BackgroundTransparency = 0.08 })
	typewrite(introStory, m.story)
	task.delay(2.5, function()
		typewrite(introGoal, "ЦЕЛЬ: " .. m.goal)
	end)
	mapLabel.Text = (m.icon or "") .. " " .. m.name
	mapLabel.TextColor3 = m.color or Colors.Dim
	diffLabel.Text = (d.icon or "") .. " " .. d.name .. (d.blind and "  ·  оно слепое: не шуми" or "  ·  оно видит: не свети в глаза")
	diffLabel.TextColor3 = d.color or Colors.Dim
end
local function hideIntro()
	if intro.Visible then
		UI.tween(intro, 0.8, { BackgroundTransparency = 1 })
		task.delay(0.8, function()
			intro.Visible = false
		end)
	end
end

Remotes.RoundUpdate.OnClientEvent:Connect(function(kind, a, b)
	if kind == "message" then
		showMessage(a, b, 5)
	elseif kind == "waiting" then
		introWait.Text = "раунд начнётся через " .. tostring(a)
		if not intro.Visible then
			showMessage("ОЖИДАНИЕ ИГРОКОВ...  " .. tostring(a), Colors.Dim, 1.2)
		end
	elseif kind == "intro" then
		showIntro(a, b)
	end
end)
workspace:GetAttributeChangedSignal("RoundState"):Connect(function()
	if workspace:GetAttribute("RoundState") == "Playing" then
		hideIntro()
	end
end)

-- БЕГ / ПРИСЯДКА ----------------------------------------------------------
local stamina = P.StaminaMax
local sprintHeld = false
local exhausted = false
local sprinting = false
local crouching = false
local bobT = 0
local shake = 0
local scaring = false
local noiseLevel = 0

local function setCrouch(on)
	if crouching == on then
		return
	end
	crouching = on
	Remotes.Action:FireServer("crouch", on)
	Sound.play("Cloth", nil, { Volume = 0.5 })
end

ContextActionService:BindAction("Sprint", function(_, state)
	if state == Enum.UserInputState.Begin then
		sprintHeld = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		sprintHeld = false
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("Sprint", "БЕГ")
ContextActionService:SetPosition("Sprint", UDim2.new(1, -170, 1, -150))

ContextActionService:BindAction("Crouch", function(_, state)
	if state == Enum.UserInputState.Begin then
		if settings.crouchToggle then
			setCrouch(not crouching)
		else
			setCrouch(true)
		end
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if not settings.crouchToggle then
			setCrouch(false)
		end
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle("Crouch", "ПРИСЕСТЬ")
ContextActionService:SetPosition("Crouch", UDim2.new(1, -110, 1, -215))

-- МОНСТР ------------------------------------------------------------------
local monster = nil
local lastSting = 0
local function onMonster(m)
	monster = m
	Animator.track(m)
	m:GetAttributeChangedSignal("State"):Connect(function()
		local s = m:GetAttribute("State")
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local root = m:FindFirstChild("HumanoidRootPart")
		if s == "Chase" and hrp and root and (hrp.Position - root.Position).Magnitude < 80 then
			if os.clock() - lastSting > 12 then
				lastSting = os.clock()
				Sound.play("ChaseSting", nil, { Volume = 0.9 })
				if not player:GetAttribute("Perk_nerves") then
					fl.forceFlicker = 0.6
					task.delay(1.2, function()
						fl.forceFlicker = 0
					end)
				end
			end
		end
	end)
end
workspace.ChildAdded:Connect(function(c)
	if c.Name == "Monster" and c:IsA("Model") then
		task.wait(0.2)
		onMonster(c)
	end
end)
if workspace:FindFirstChild("Monster") then
	onMonster(workspace.Monster)
end
Animator.onFootstep = function(pos, intensity)
	shake = math.max(shake, Animator.shakeAmountFor(pos) * (intensity or 1))
end

-- ЭХО-КРИК (Кошмар): красная волна, экран дрожит; если двигаешься — предупреждение
local sonarRing = UI.new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(120, 0, 20),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 60,
	Parent = gui,
})
Remotes.Sonar.OnClientEvent:Connect(function(origin)
	local cam = workspace.CurrentCamera
	local d = cam and (cam.CFrame.Position - origin).Magnitude or 999
	local k = math.clamp(1 - d / 250, 0, 1)
	if k <= 0 then
		return
	end
	shake = math.max(shake, 1.5 * k)
	sonarRing.BackgroundTransparency = 1 - 0.55 * k
	UI.tween(sonarRing, 1.2, { BackgroundTransparency = 1 })
	Sound.play("Static", nil, { Volume = 0.3 * k })
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.MoveDirection.Magnitude > 0.1 and not player:GetAttribute("Hiding") then
		showMessage("ЗАМРИ!", Colors.BrightRed, 1.2)
	end
end)

-- ЗВУКИ АТМОСФЕРЫ ------------------------------------------------------
local ambience = nil
local function startAmbience()
	local mapId = workspace:GetAttribute("Map")
	local key = Config.getMap(mapId).ambience or "Ambience"
	if ambience then
		ambience:Destroy()
	end
	ambience = Sound.make(key, nil, { Looped = true, Volume = 0.45 }) or Sound.make("Ambience", nil, { Looped = true, Volume = 0.45 })
	if ambience then
		ambience:Play()
	end
end
startAmbience()
workspace:GetAttributeChangedSignal("Map"):Connect(startAmbience)
local heartbeat = Sound.make("Heartbeat", nil, { Looped = true, Volume = 0 })
if heartbeat then
	heartbeat:Play()
end
local breathing = Sound.make("Breathing", nil, { Looped = true, Volume = 0 })
if breathing then
	breathing:Play()
end

task.spawn(function()
	while true do
		task.wait(math.random(18, 45))
		local cam = workspace.CurrentCamera
		if cam and not scaring and not player:GetAttribute("Dead") then
			local r = math.random()
			local a = math.random() * math.pi * 2
			if r < 0.4 then
				-- шёпот прямо за спиной
				local behind = cam.CFrame.Position - cam.CFrame.LookVector * 4 + Vector3.new(math.cos(a), 0, math.sin(a)) * 2
				Sound.playAt("Whisper", behind, { Volume = 0.7, RollOffMaxDistance = 20 })
			elseif r < 0.75 then
				local far = cam.CFrame.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * 45
				Sound.playAt("MetalBang", far, { Volume = 1, RollOffMinDistance = 20, RollOffMaxDistance = 150 })
			else
				Sound.play("Static", nil, { Volume = 0.25 })
				fl.forceFlicker = 0.8
				task.wait(0.7)
				fl.forceFlicker = 0
			end
		end
	end
end)

-- СВЕТ НА КАРТЕ ------------------------------------------------------------
local lamps = {}
local function collectLamps()
	for _, l in ipairs(lamps) do
		if l.buzz then
			l.buzz:Destroy()
		end
	end
	lamps = {}
	local map = workspace:FindFirstChild("Map")
	local lightsFolder = map and map:FindFirstChild("Lights")
	if not lightsFolder then
		return
	end
	local buzzCount = 0
	for _, part in ipairs(lightsFolder:GetDescendants()) do
		if part:IsA("BasePart") and (part.Name == "Lamp" or part.Name == "FlickerLamp" or part.Name == "Emergency") then
			local light = part:FindFirstChildWhichIsA("Light")
			local l = {
				part = part,
				light = light,
				kind = part.Name,
				color = part.Color,
				bright = light and light.Brightness or 1,
				next = 0,
				state = nil,
				mult = nil,
			}
			table.insert(lamps, l)
			if part.Name == "FlickerLamp" and buzzCount < 30 then
				buzzCount += 1
				local s = Sound.make("LightBuzz", part, { Looped = true, Volume = 0.35, RollOffMinDistance = 4, RollOffMaxDistance = 28 })
				if s then
					l.buzz = s
					s:Play()
				end
			end
		end
	end
end
collectLamps()
workspace.ChildAdded:Connect(function(c)
	if c.Name == "Map" then
		task.wait(0.5)
		collectLamps()
	end
end)

local function setLamp(l, on, mult)
	mult = mult or 1
	if l.state == on and l.mult == mult then
		return
	end
	l.state = on
	l.mult = mult
	if l.light then
		l.light.Enabled = on
		l.light.Brightness = l.bright * mult
	end
	l.part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	l.part.Color = on and l.color or Color3.fromRGB(38, 36, 32)
	if l.buzz then
		l.buzz.Volume = on and 0.35 or 0.05
	end
end

task.spawn(function()
	while true do
		task.wait(0.05)
		local power = workspace:GetAttribute("Power") == true
		local now = os.clock()
		local mpos = nil
		if monster and monster.Parent then
			local root = monster:FindFirstChild("HumanoidRootPart")
			mpos = root and root.Position
		end
		for _, l in ipairs(lamps) do
			if l.part.Parent then
				local near = mpos and (l.part.Position - mpos).Magnitude < 30
				if l.kind == "Emergency" then
					local pulse = 0.65 + 0.35 * math.sin(now * (power and 6 or 1.5) + l.part.Position.X)
					setLamp(l, true, math.floor(pulse * 10) / 10)
				elseif l.kind == "Lamp" then
					if near then
						setLamp(l, power and math.random() > 0.45, 1)
					else
						setLamp(l, power, 1)
					end
				else -- FlickerLamp
					if now >= l.next or near then
						local on = not l.state
						if near then
							on = math.random() > 0.6
						end
						setLamp(l, on, power and 1 or 0.45)
						if on then
							l.next = now + (math.random() < 0.3 and 0.05 + math.random() * 0.1 or 0.6 + math.random() * (power and 4 or 2))
						else
							l.next = now + 0.04 + math.random() * (power and 0.2 or 1.4)
						end
					end
				end
			end
		end
	end
end)

workspace:GetAttributeChangedSignal("Power"):Connect(function()
	if workspace:GetAttribute("Power") then
		task.spawn(function()
			for _ = 1, 4 do
				flash.BackgroundColor3 = Color3.new(1, 0, 0)
				UI.tween(flash, 0.15, { BackgroundTransparency = 0.75 })
				task.wait(0.35)
				UI.tween(flash, 0.35, { BackgroundTransparency = 1 })
				task.wait(0.45)
			end
		end)
	end
end)

-- СКРИМЕР ----------------------------------------------------------------
local deadText = UI.label({
	Text = "ТЫ МЁРТВ",
	Font = UI.FontTitle,
	TextSize = 96,
	TextColor3 = Colors.BrightRed,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	ZIndex = 99,
	Parent = gui,
})
local blackout = UI.new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 98,
	Parent = gui,
})

local function jumpscare(m)
	if scaring then
		return
	end
	scaring = true
	local cam = workspace.CurrentCamera
	local oldFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	fl.disabled = true
	local head = m and m:FindFirstChild("Head")
	local face = head and head:FindFirstChild("FaceCam")

	-- свет в лицо монстру, чтобы было видно каждую деталь
	local faceLight = Instance.new("PointLight")
	faceLight.Color = Color3.fromRGB(255, 200, 180)
	faceLight.Range = 9
	faceLight.Brightness = 5
	faceLight.Shadows = false
	faceLight.Parent = head or workspace.Terrain
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Contrast = 0.5
	cc.Saturation = -0.4
	cc.TintColor = Color3.fromRGB(255, 200, 200)
	cc.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = Lighting

	Sound.play("MonsterScream", nil, { Volume = 2 })
	Sound.play("Static", nil, { Volume = 0.8 })
	if heartbeat then
		heartbeat.Volume = 0
	end

	local startCF = cam.CFrame
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local n = Vector3.new(
			math.noise(t * 22, 1.3),
			math.noise(t * 22, 7.1),
			math.noise(t * 22, 3.7)
		)
		local sh = n * (0.35 * math.exp(-t * 0.8) + 0.08)
		if head and head.Parent then
			local f = face and face.WorldCFrame or (head.CFrame * CFrame.new(0, 0.2, -0.8))
			-- рывок вперёд: с 3.4 до 0.9 стада за 0.35 сек, потом "дышит" в лицо
			local dist = (t < 0.35) and (3.4 - (t / 0.35) * 2.5) or (0.9 + math.sin(t * 9) * 0.12)
			local pos = f.Position + f.LookVector * dist + sh
			cam.CFrame = CFrame.lookAt(pos, f.Position + sh * 0.3) * CFrame.Angles(0, 0, math.sin(t * 37) * 0.06)
		else
			cam.CFrame = startCF * CFrame.new(sh * 3) * CFrame.Angles(sh.X * 0.3, sh.Y * 0.3, 0)
		end
		cam.FieldOfView = 55 + 30 * math.exp(-t * 7) + math.sin(t * 50) * 2
		local strobe = math.floor(t * 15) % 2 == 0
		flash.BackgroundColor3 = strobe and Color3.fromRGB(160, 0, 0) or Color3.new(0, 0, 0)
		flash.BackgroundTransparency = strobe and (0.6 + math.random() * 0.25) or (0.75 + math.random() * 0.2)
		blur.Size = math.random() < 0.15 and 12 or 2
	end)

	task.wait(1.9)
	conn:Disconnect()
	flash.BackgroundTransparency = 1
	blackout.BackgroundTransparency = 0
	Sound.play("Static", nil, { Volume = 1, PlaybackSpeed = 0.8 })
	for i = 1, 14 do
		deadText.TextTransparency = (i % 2 == 0) and 0 or 0.7
		deadText.Position = UDim2.fromOffset(math.random(-6, 6), math.random(-4, 4))
		task.wait(0.05)
	end
	deadText.TextTransparency = 0
	deadText.Position = UDim2.new()
	task.wait(1.6)
	UI.tween(deadText, 1, { TextTransparency = 1 })
	UI.tween(blackout, 1.4, { BackgroundTransparency = 1 })
	faceLight:Destroy()
	cc:Destroy()
	blur:Destroy()
	cam.FieldOfView = oldFov
	cam.CameraType = Enum.CameraType.Custom
	fl.disabled = false
	scaring = false
end
Remotes.Jumpscare.OnClientEvent:Connect(function(m)
	task.spawn(jumpscare, m)
end)

-- НАБЛЮДЕНИЕ И ВОЗРОЖДЕНИЕ -------------------------------------------------
local spec = UI.new("Frame", {
	Name = "Spectate",
	Size = UDim2.fromOffset(520, 104),
	Position = UDim2.new(0.5, 0, 1, -30),
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundColor3 = Colors.Panel,
	BackgroundTransparency = 0.2,
	Visible = false,
	ZIndex = 30,
	Parent = gui,
}, { UI.corner(4), UI.stroke(Colors.Red, 1, 0.3) })
local specName = UI.label({
	Text = "НАБЛЮДЕНИЕ",
	Font = UI.FontTitle,
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, -120, 0, 36),
	Position = UDim2.fromOffset(60, 6),
	ZIndex = 31,
	Parent = spec,
})
local specIndex = 1
local function aliveOthers()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and not p:GetAttribute("Dead") and not p:GetAttribute("Escaped") then
			local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 then
				table.insert(list, p)
			end
		end
	end
	return list
end
local function applySpectate()
	local list = aliveOthers()
	local cam = workspace.CurrentCamera
	if #list == 0 then
		specName.Text = "НЕКОГО НАБЛЮДАТЬ..."
		return
	end
	specIndex = ((specIndex - 1) % #list) + 1
	local target = list[specIndex]
	local h = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if h and not scaring then
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = h
	end
	specName.Text = "НАБЛЮДЕНИЕ: " .. target.DisplayName
end
UI.button({ Text = "<", Size = UDim2.fromOffset(44, 36), Position = UDim2.fromOffset(10, 6), ZIndex = 31, Parent = spec }, function()
	specIndex -= 1
	applySpectate()
end)
UI.button({ Text = ">", Size = UDim2.fromOffset(44, 36), Position = UDim2.new(1, -54, 0, 6), ZIndex = 31, Parent = spec }, function()
	specIndex += 1
	applySpectate()
end)
local reviveBtn = UI.button({
	Text = "✚ ВОЗРОДИТЬСЯ",
	Size = UDim2.new(1, -20, 0, 44),
	Position = UDim2.fromOffset(10, 52),
	TextColor3 = Colors.Gold,
	ZIndex = 31,
	Parent = spec,
}, function()
	local d = ClientData.get()
	if d and (d.revives or 0) > 0 then
		local ok, text = Remotes.UseRevive:InvokeServer()
		UI.toast(gui, text or "", ok and Colors.Green or Colors.Red)
	else
		local id = Config.Products.Revive
		if id and id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, id)
		else
			UI.toast(gui, "Продукт «Возрождение» не настроен (ID = 0 в Config)", Colors.Red)
		end
	end
end)
local function refreshReviveText()
	local d = ClientData.get()
	local n = d and d.revives or 0
	reviveBtn.Text = n > 0 and ("✚ ВОЗРОДИТЬСЯ  (жетонов: " .. n .. ")") or "✚ ВОЗРОДИТЬСЯ ЗА R$"
end
ClientData.Changed:Connect(refreshReviveText)
refreshReviveText()

local wasDead = false
local function setDeadMode(dead)
	if dead == wasDead then
		return
	end
	wasDead = dead
	if dead then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = 14
		player.CameraMinZoomDistance = 8
	else
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		local char = player.Character
		local h = char and char:FindFirstChildOfClass("Humanoid")
		if h then
			workspace.CurrentCamera.CameraSubject = h
		end
	end
end

player.CharacterAdded:Connect(function(char)
	local h = char:WaitForChild("Humanoid")
	stamina = P.StaminaMax * (player:GetAttribute("Perk_stamina") or 1)
	exhausted = false
	crouching = false
	setDeadMode(false)
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	workspace.CurrentCamera.CameraSubject = h
end)

-- НАСТРОЙКИ (M) ----------------------------------------------------------------
local setWin = UI.window(gui, "НАСТРОЙКИ", UDim2.fromOffset(540, 420))
setWin.frame.ZIndex = 40
local setList = UI.new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 41,
	Parent = setWin.content,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
local function settingRow(order, labelText)
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 41, Parent = setList })
	UI.label({ Text = labelText, Font = UI.FontBold, TextSize = 17, Size = UDim2.new(0.42, 0, 1, 0), ZIndex = 41, Parent = row })
	return row
end
local sliders = {}
for i, s in ipairs({ { "master", "ОБЩАЯ ГРОМКОСТЬ" }, { "music", "МУЗЫКА И АТМОСФЕРА" }, { "sfx", "ЭФФЕКТЫ" } }) do
	local row = settingRow(i, s[2])
	sliders[s[1]] = UI.slider({ Size = UDim2.new(0.56, 0, 1, 0), Position = UDim2.new(0.44, 0, 0, 0), ZIndex = 42, Parent = row }, settings[s[1]] or 1, function(v)
		settings[s[1]] = v
		applySettings()
		saveSettings()
	end)
end
local sensRow = settingRow(4, "ЧУВСТВИТЕЛЬНОСТЬ МЫШИ")
sliders.sensitivity = UI.slider({ Size = UDim2.new(0.56, 0, 1, 0), Position = UDim2.new(0.44, 0, 0, 0), ZIndex = 42, Parent = sensRow }, (settings.sensitivity or 1) / 3, function(v)
	settings.sensitivity = math.max(0.2, v * 3)
	applySettings()
	saveSettings()
end)
local crouchRow = settingRow(5, "ПРИСЯДКА")
local crouchBtn = UI.button({ Text = "", TextSize = 15, Size = UDim2.fromOffset(200, 36), Position = UDim2.new(1, -200, 0, 2), ZIndex = 42, Parent = crouchRow }, function()
	settings.crouchToggle = not settings.crouchToggle
	saveSettings()
end)
local function refreshSettingsUI()
	for k, s in pairs(sliders) do
		if k == "sensitivity" then
			s.set((settings.sensitivity or 1) / 3)
		else
			s.set(settings[k] or 1)
		end
	end
	crouchBtn.Text = settings.crouchToggle and "ПЕРЕКЛЮЧЕНИЕ (C)" or "УДЕРЖАНИЕ (C)"
end
crouchBtn.Activated:Connect(refreshSettingsUI)
UI.label({
	Text = "Громкость применяется сразу и сохраняется в профиле.",
	Font = UI.FontMono,
	TextSize = 13,
	TextColor3 = Colors.Dim,
	Size = UDim2.new(1, 0, 0, 30),
	LayoutOrder = 6,
	ZIndex = 41,
	Parent = setList,
})
local function toggleSettings()
	if setWin.frame.Visible then
		setWin.close()
	else
		refreshSettingsUI()
		setWin.open()
	end
end
ContextActionService:BindAction("SettingsMenu", function(_, state)
	if state == Enum.UserInputState.Begin then
		toggleSettings()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)
UI.button({ Text = "⚙", TextSize = 22, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -56, 0, 16), ZIndex = 6, Parent = gui }, toggleSettings)

-- ИТОГИ РАУНДА -----------------------------------------------------------
local results = UI.new("Frame", {
	Name = "Results",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(4, 2, 2),
	BackgroundTransparency = 0.15,
	Visible = false,
	ZIndex = 80,
	Parent = gui,
})
local resTitle = UI.label({
	Text = "",
	Font = UI.FontTitle,
	TextSize = 72,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 90),
	Position = UDim2.fromScale(0, 0.18),
	ZIndex = 81,
	Parent = results,
})
local resBody = UI.label({
	Text = "",
	Font = UI.FontMono,
	TextSize = 22,
	TextColor3 = Colors.Text,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Top,
	Size = UDim2.new(1, 0, 0, 260),
	Position = UDim2.fromScale(0, 0.36),
	ZIndex = 81,
	Parent = results,
})
Remotes.Results.OnClientEvent:Connect(function(r)
	while scaring do
		task.wait(0.2)
	end
	hideIntro()
	results.Visible = true
	results.BackgroundTransparency = 1
	UI.tween(results, 0.8, { BackgroundTransparency = 0.15 })
	resTitle.Text = r.escaped and "ТЫ СБЕЖАЛ" or "ТЫ НЕ ВЫБРАЛСЯ"
	resTitle.TextColor3 = r.escaped and Colors.Green or Colors.BrightRed
	local mins = math.floor((r.time or 0) / 60)
	local secs = (r.time or 0) % 60
	local m = Config.getMap(r.map)
	local d = Config.getDifficulty(r.difficulty)
	resBody.Text = string.format(
		"%s · %s\nВРЕМЯ: %d:%02d\nГЕНЕРАТОРОВ ПОЧИНЕНО ТОБОЙ: %d   ПРЕДОХРАНИТЕЛЕЙ: %d\n\n+%d МОНЕТ%s\n+%d XP БАТЛПАССА\n\nвозвращение в лобби...",
		m.name,
		d.name,
		mins,
		secs,
		r.generators or 0,
		r.fuses or 0,
		r.coins or 0,
		r.vip and "  (VIP x2)" or "",
		r.xp or 0
	)
	Sound.play(r.escaped and "Purchase" or "Static", nil, { Volume = 0.6 })
end)

Remotes.Teleporting.OnClientEvent:Connect(function()
	Sound.play("Teleport", nil, { Volume = 0.8 })
	fadeText.Text = "ВОЗВРАЩЕНИЕ..."
	UI.tween(fade, 1, { BackgroundTransparency = 0 })
end)

-- ГЛАВНЫЙ ЦИКЛ ------------------------------------------------------------
local specTimer = 0
local camCrouch = 0
RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	local dead = player:GetAttribute("Dead") == true
	local hiding = player:GetAttribute("Hiding") == true
	local serverCrouch = player:GetAttribute("Crouching") == true

	if hum and hrp and hum.Health > 0 and not scaring and not dead then
		local moving = hum.MoveDirection.Magnitude > 0.1
		local staminaMax = P.StaminaMax * (player:GetAttribute("Perk_stamina") or 1)
		local want = sprintHeld and moving and not exhausted and not hiding
		if want and crouching then
			setCrouch(false)
		end
		if want then
			stamina = math.max(0, stamina - P.StaminaDrain * dt)
			if stamina <= 0 then
				exhausted = true
			end
		else
			local regen = P.StaminaRegen * (player:GetAttribute("Perk_stamina") or 1)
			stamina = math.min(staminaMax, stamina + regen * dt * (moving and 0.6 or 1))
			if exhausted and stamina > 30 then
				exhausted = false
			end
		end
		if want ~= sprinting then
			sprinting = want
			Remotes.Action:FireServer("sprint", sprinting)
		end
		if hiding and crouching then
			setCrouch(false)
		end
		local chased = false
		if monster and monster.Parent and monster:GetAttribute("State") == "Chase" then
			local root = monster:FindFirstChild("HumanoidRootPart")
			chased = root and (root.Position - hrp.Position).Magnitude < 60
		end
		local speed = P.WalkSpeed
		if sprinting then
			speed = P.SprintSpeed * ((chased and player:GetAttribute("Perk_sprint")) or 1)
		elseif crouching then
			speed = P.CrouchSpeed
		end
		hum.WalkSpeed = speed

		-- покачивание камеры при ходьбе + тряска от шагов монстра + присядка
		if moving and hum.FloorMaterial ~= Enum.Material.Air then
			bobT += dt * (sprinting and 13 or (crouching and 6 or 8.5))
		end
		local amp = moving and (sprinting and 0.2 or (crouching and 0.05 or 0.09)) or 0
		local bob = Vector3.new(math.sin(bobT) * amp, math.abs(math.cos(bobT)) * amp * 1.3, 0)
		shake = math.max(0, shake - dt * 2.5)
		local sh = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shake * 0.5
		camCrouch += ((crouching and -1.45 or 0) - camCrouch) * math.min(1, dt * 8)
		hum.CameraOffset = hum.CameraOffset:Lerp(bob + sh + Vector3.new(0, camCrouch, 0), math.min(1, dt * 12))
		local targetFov = sprinting and 80 or (crouching and 64 or 70)
		cam.FieldOfView += (targetFov - cam.FieldOfView) * math.min(1, dt * 6)

		-- индикатор шума
		local vel = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude
		local target
		if sprinting and vel > 4 then
			target = 1
		elseif crouching then
			target = (vel > 1) and 0.15 or 0.03
		elseif vel > 1 then
			target = 0.45
		else
			target = 0.03
		end
		if player:GetAttribute("Repairing") then
			target = math.max(target, 0.8)
		end
		if hiding then
			target = 0
		end
		noiseLevel += (target - noiseLevel) * math.min(1, dt * 6)
	elseif sprinting then
		sprinting = false
		Remotes.Action:FireServer("sprint", false)
	end

	-- сердцебиение / дыхание в присяде
	if heartbeat and not scaring then
		local k = 0
		if monster and monster.Parent and hrp and not dead then
			local root = monster:FindFirstChild("HumanoidRootPart")
			if root then
				k = math.clamp(1 - (root.Position - hrp.Position).Magnitude / 70, 0, 1)
			end
		end
		heartbeat.Volume += (k * 1.3 - heartbeat.Volume) * math.min(1, dt * 3)
		heartbeat.PlaybackSpeed = 0.85 + k * 0.75
	end
	if breathing then
		local want = (crouching and not dead and not hiding) and 0.5 or 0
		breathing.Volume += (want - breathing.Volume) * math.min(1, dt * 4)
	end

	-- HUD
	local battery = player:GetAttribute("Battery") or 100
	batteryFill.Size = UDim2.fromScale(math.clamp(battery / 100, 0, 1), 1)
	batteryFill.BackgroundColor3 = battery < 20 and Colors.BrightRed or Color3.fromRGB(230, 220, 160)
	local spare = player:GetAttribute("SpareBatteries") or 0
	batteryLabel.Text = string.format("ФОНАРИК %d%%%s%s", math.floor(battery), player:GetAttribute("FlashlightOn") and "  ●" or "", spare > 0 and ("  +" .. spare) or "")
	local staminaMax = P.StaminaMax * (player:GetAttribute("Perk_stamina") or 1)
	staminaFill.Size = UDim2.fromScale(math.clamp(stamina / staminaMax, 0, 1), 1)
	staminaFill.BackgroundColor3 = exhausted and Color3.fromRGB(90, 20, 20) or Color3.fromRGB(170, 40, 40)
	staminaLabel.Text = exhausted and "ДЫХАНИЕ — ЗАДЫХАЕШЬСЯ" or "ДЫХАНИЕ"
	noiseFill.Size = UDim2.fromScale(math.clamp(noiseLevel, 0, 1), 1)
	noiseFill.BackgroundColor3 = noiseLevel > 0.6 and Colors.BrightRed or Color3.fromRGB(200, 120, 40)
	noiseLabel.Text = (serverCrouch or crouching) and "ШУМ · ПРИСЯДКА" or (noiseLevel > 0.6 and "ШУМ · ОНО СЛЫШИТ" or "ШУМ")
	batteryHolder.Visible = not dead
	staminaHolder.Visible = not dead
	noiseHolder.Visible = not dead

	local done = workspace:GetAttribute("GensDone") or 0
	local needed = workspace:GetAttribute("GensNeeded") or 3
	if workspace:GetAttribute("Power") then
		objective.Text = "СВЕТ ВКЛЮЧЁН — ВОРОТА ОТКРЫТЫ. БЕГИ К ВЫХОДУ"
		objective.TextColor3 = Colors.BrightRed
	else
		objective.Text = string.format("ГЕНЕРАТОРЫ  %d/%d", done, needed)
		objective.TextColor3 = Colors.Text
	end
	local left = workspace:GetAttribute("TimeLeft") or 0
	timerLabel.Text = string.format("%02d:%02d", math.floor(left / 60), left % 60)
	timerLabel.TextColor3 = left < 60 and Colors.BrightRed or Colors.Dim
	carryLabel.Visible = player:GetAttribute("Fuse") == true and not dead
	lockerOverlay.Visible = hiding and not scaring
	fl.disabled = scaring or hiding or dead
	fl.steady = player:GetAttribute("Perk_nerves") == 1

	local repairing = player:GetAttribute("Repairing")
	repairHolder.Visible = repairing ~= nil and not dead
	if repairing then
		repairFill.Size = UDim2.fromScale(math.clamp(player:GetAttribute("RepairProgress") or 0, 0, 1), 1)
	end

	-- наблюдение
	local spectating = dead and workspace:GetAttribute("RoundState") == "Playing"
	setDeadMode(dead)
	spec.Visible = spectating and not scaring and not results.Visible
	if spectating and not scaring then
		specTimer += dt
		if specTimer > 1 then
			specTimer = 0
			applySpectate()
		end
	end
end)
