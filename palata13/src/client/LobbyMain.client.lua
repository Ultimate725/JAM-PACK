--[[
	ПАЛАТА 13 — клиент ЛОББИ.
	Главное меню: «запись с камеры» — коридор, фонарик за мышкой, блэкауты, Пациент подходит
	ближе с каждым затемнением, а в конце — в лицо. Вкладки: ИГРАТЬ / КАРТЫ / МАГАЗИН / БАТЛПАСС / ПРОФИЛЬ / НАСТРОЙКИ.
	Лобби: HUD, киоски (касса / фонари / аптека / регистратура), доска батлпасса, план больницы,
	пульт врат (карта, сложность, число игроков), настройки с ползунками громкости.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sound = require(Shared:WaitForChild("Sound"))
local UI = require(Shared:WaitForChild("UI"))
local ClientData = require(Shared:WaitForChild("ClientData"))
local BattlePass = require(Shared:WaitForChild("BattlePass"))
local FL = require(Shared:WaitForChild("FlashlightClient"))
local Animator = require(Shared:WaitForChild("MonsterAnimator"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Colors = UI.Colors

local Lobby = workspace:WaitForChild("Lobby")
local camPart = Lobby:WaitForChild("MenuCamera")
local menuMonster = Lobby:FindFirstChild("MenuMonster")
local menuPoints = Lobby:FindFirstChild("MenuMonsterPoints")
local menuScene = Lobby:FindFirstChild("MenuScene")

ClientData.start()
Animator.start()

local settings = { master = 1, music = 0.6, sfx = 1, sensitivity = 1, grain = true, flicker = true, crouchToggle = true }
local inMenu = true
local fl = nil

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

-- отключаем управление, пока мы в меню
local controls = nil
task.spawn(function()
	local ok, pm = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and pm then
		controls = pm:GetControls()
		if inMenu and controls then
			controls:Disable()
		end
	end
end)
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- ЗВУК ----------------------------------------------------------------------
local menuMusic = Sound.make("MenuMusic", nil, { Looped = true, Volume = 1 })
if menuMusic then
	menuMusic:Play()
end
local ambience = Sound.make("Ambience", nil, { Looped = true, Volume = 0 })
local menuHeart = Sound.make("Heartbeat", nil, { Looped = true, Volume = 0 })
if menuHeart then
	menuHeart:Play()
end
local menuBreath = Sound.make("MonsterBreath", nil, { Looped = true, Volume = 0 })
if menuBreath then
	menuBreath:Play()
end

local function applyVolumes()
	if menuMusic then
		menuMusic.Volume = inMenu and 1 or 0
	end
	if ambience then
		ambience.Volume = inMenu and 0 or 0.55
	end
end

-- GUI -----------------------------------------------------------------------
local gui = UI.new("ScreenGui", {
	Name = "LobbyUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
	Parent = player:WaitForChild("PlayerGui"),
})

local fade = UI.new("Frame", {
	Name = "Fade",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	ZIndex = 100,
	Parent = gui,
})
local fadeText = UI.label({
	Text = "",
	Font = UI.FontTitle,
	TextSize = 46,
	TextColor3 = Colors.BrightRed,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 101,
	Parent = fade,
})
local function fadeTo(transparency, time)
	UI.tween(fade, time or 0.6, { BackgroundTransparency = transparency })
	UI.tween(fadeText, time or 0.6, { TextTransparency = transparency })
end

local function toast(text, color)
	UI.toast(gui, text, color)
end

-- ============================ ГЛАВНОЕ МЕНЮ ============================
local menu = UI.new("Frame", {
	Name = "Menu",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = gui,
})
-- затемнение сцены во время "блэкаута"
local sceneDark = UI.new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 1,
	Parent = menu,
})
UI.vignette(menu, 0.8)
UI.new("Frame", {
	Size = UDim2.fromScale(0.6, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	ZIndex = 2,
	Parent = menu,
}, {
	UI.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.6, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}),
})

-- царапины, пыль и VHS-полосы старой плёнки
local grain = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = menu })
local scratches, dust, vhsLines = {}, {}, {}
for i = 1, 4 do
	scratches[i] = UI.new("Frame", {
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Color3.fromRGB(220, 210, 200),
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = grain,
	})
end
for i = 1, 26 do
	dust[i] = UI.new("Frame", {
		Size = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.fromRGB(230, 220, 210),
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = grain,
	})
end
for i = 1, 3 do
	vhsLines[i] = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Color3.fromRGB(200, 200, 200),
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = grain,
	})
end
-- "REC" и таймкод: это запись с камеры наблюдения
local recDot = UI.new("Frame", {
	Size = UDim2.fromOffset(12, 12),
	Position = UDim2.new(1, -150, 0, 26),
	BackgroundColor3 = Color3.fromRGB(235, 30, 30),
	BorderSizePixel = 0,
	ZIndex = 6,
	Parent = menu,
}, { UI.corner(6) })
local recLabel = UI.label({
	Text = "REC  КАМ-13  03:13:00",
	Font = UI.FontMono,
	TextSize = 15,
	TextColor3 = Color3.fromRGB(235, 225, 215),
	Size = UDim2.fromOffset(300, 20),
	Position = UDim2.new(1, -132, 0, 22),
	ZIndex = 6,
	Parent = menu,
})

local titleHolder, stopTitle = UI.glitchTitle(menu, "ПАЛАТА 13", UDim2.fromOffset(640, 130), UDim2.new(0.06, 0, 0.13, 0), 112)
local subtitle = UI.label({
	Text = "",
	Font = UI.FontMono,
	TextSize = 20,
	TextColor3 = Colors.Red,
	Size = UDim2.fromOffset(560, 26),
	Position = UDim2.new(0.06, 8, 0.13, 136),
	ZIndex = 6,
	Parent = menu,
})
task.spawn(function()
	local phrases = {
		"оно не спит",
		"оно помнит твоё имя",
		"не свети ему в лицо",
		"палата 13 свободна. пока.",
		"в морге стучат изнутри",
		"в лесу звонит колокол, а звонаря нет",
		"если оно слепое — не дыши",
	}
	local i = 0
	while inMenu do
		i = i % #phrases + 1
		local p = phrases[i]
		local len = utf8.len(p) or #p
		for n = 1, len do
			if not inMenu then
				return
			end
			local cut = utf8.offset(p, n + 1)
			subtitle.Text = (cut and string.sub(p, 1, cut - 1) or p) .. "_"
			task.wait(0.06 + math.random() * 0.06)
		end
		for _ = 1, 8 do
			subtitle.Text = p .. ((os.clock() * 2) % 2 < 1 and "_" or "")
			task.wait(0.45)
		end
	end
end)

local buttonsHolder = UI.new("Frame", {
	Size = UDim2.fromOffset(380, 380),
	Position = UDim2.fromScale(0.06, 0.4),
	BackgroundTransparency = 1,
	ZIndex = 6,
	Parent = menu,
}, {
	UI.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local menuButtons = {}
local function menuButton(text, order, onClick)
	local b = UI.button({
		Text = "  " .. text,
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 38,
		LayoutOrder = order,
		ZIndex = 6,
		NoStroke = true,
		Parent = buttonsHolder,
	}, onClick)
	local line = UI.new("Frame", {
		Size = UDim2.new(0, 0, 0, 2),
		Position = UDim2.new(0, 10, 1, -6),
		BackgroundColor3 = Colors.Red,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = b,
	})
	b.MouseEnter:Connect(function()
		b.Text = "› " .. text
		UI.tween(line, 0.2, { Size = UDim2.new(0.75, 0, 0, 2) })
	end)
	b.MouseLeave:Connect(function()
		b.Text = "  " .. text
		UI.tween(line, 0.25, { Size = UDim2.new(0, 0, 0, 2) })
	end)
	table.insert(menuButtons, b)
	return b
end

UI.label({
	Text = Config.Version .. "   ·   играй в наушниках   ·   не оставайся в темноте   ·   3 карты · 4 сложности",
	Font = UI.FontMono,
	TextSize = 13,
	TextColor3 = Colors.Dim,
	Size = UDim2.fromOffset(700, 18),
	Position = UDim2.new(0.06, 8, 1, -40),
	ZIndex = 6,
	Parent = menu,
})
local menuStats = UI.label({
	Text = "",
	Font = UI.FontMono,
	TextSize = 14,
	TextColor3 = Colors.Dim,
	TextXAlignment = Enum.TextXAlignment.Right,
	Size = UDim2.fromOffset(420, 40),
	Position = UDim2.new(1, -24, 1, -24),
	AnchorPoint = Vector2.new(1, 1),
	ZIndex = 6,
	Parent = menu,
})
-- предупреждение в самом конце "записи"
local warnText = UI.label({
	Text = "",
	Font = UI.FontTitle,
	TextSize = 72,
	TextColor3 = Colors.BrightRed,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	TextTransparency = 1,
	ZIndex = 9,
	Parent = menu,
})

-- фонарик меню (следит за мышкой и мигает) + пыль в луче
local menuLight = Instance.new("Part")
menuLight.Name = "MenuFlashlight"
menuLight.Anchored = true
menuLight.CanCollide = false
menuLight.CanQuery = false
menuLight.CanTouch = false
menuLight.Transparency = 1
menuLight.Size = Vector3.new(0.2, 0.2, 0.2)
menuLight.Parent = workspace
local spot = Instance.new("SpotLight")
spot.Face = Enum.NormalId.Front
spot.Angle = 36
spot.Range = 85
spot.Brightness = 4
spot.Shadows = true
spot.Color = Color3.fromRGB(255, 236, 205)
spot.Parent = menuLight
local spill = Instance.new("SpotLight")
spill.Face = Enum.NormalId.Front
spill.Angle = 80
spill.Range = 40
spill.Brightness = 0.5
spill.Color = Color3.fromRGB(255, 220, 190)
spill.Parent = menuLight
local motes = Instance.new("ParticleEmitter")
motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
motes.Color = ColorSequence.new(Color3.fromRGB(255, 240, 220))
motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.08) })
motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1) })
motes.Lifetime = NumberRange.new(3, 6)
motes.Rate = 18
motes.Speed = NumberRange.new(0.3, 1.2)
motes.SpreadAngle = Vector2.new(25, 25)
motes.LightEmission = 0.6
motes.EmissionDirection = Enum.NormalId.Front
motes.Parent = menuLight

local blackout = false
local burstUntil = 0
local aim = camPart.Position + camPart.CFrame.LookVector * 50
local camShake = 0
local camPush = 0 -- камера отшатывается при скримере
local stage = 1

local menuConn
menuConn = RunService.RenderStepped:Connect(function(dt)
	if not inMenu then
		return
	end
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local t = os.clock()
	local vp = cam.ViewportSize
	local mouse = UserInputService:GetMouseLocation()
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		mouse = Vector2.new(vp.X * (0.6 + math.noise(t * 0.2, 3) * 0.3), vp.Y * (0.5 + math.noise(t * 0.2, 8) * 0.25))
	end
	local mx = mouse.X / math.max(1, vp.X) - 0.5
	local my = mouse.Y / math.max(1, vp.Y) - 0.5
	camShake = math.max(0, camShake - dt * 1.5)
	camPush += (0 - camPush) * math.min(1, dt * 3)
	local sway = CFrame.Angles(
		math.noise(t * 0.25, 1.7) * 0.035 - my * 0.05 + (math.random() - 0.5) * camShake * 0.06,
		math.noise(t * 0.25, 5.3) * 0.045 - mx * 0.07 + (math.random() - 0.5) * camShake * 0.06,
		math.noise(t * 0.15, 9.1) * 0.012
	)
	-- медленный наезд камеры вперёд: дышащая "ручная" съёмка
	local dolly = math.sin(t * 0.09) * 1.5 - 1.5 + camPush
	cam.CFrame = camPart.CFrame * CFrame.new(0, math.sin(t * 0.7) * 0.05, -dolly) * sway
	cam.FieldOfView = 62 + math.sin(t * 0.3) * 1.5

	local ray = cam:ViewportPointToRay(mouse.X, mouse.Y)
	local target = ray.Origin + ray.Direction * 60
	aim = aim:Lerp(target, math.min(1, dt * 7))
	local origin = cam.CFrame.Position + cam.CFrame.RightVector * 0.9 - cam.CFrame.UpVector * 0.7
	menuLight.CFrame = CFrame.lookAt(origin, aim + Vector3.new(math.noise(t * 3, 2), math.noise(t * 3, 4), 0) * 0.6)

	-- мигание
	local on = not blackout
	if settings.flicker and not blackout then
		if t > burstUntil and math.random() < dt * 0.5 then
			burstUntil = t + 0.1 + math.random() * 0.45
		end
		if t < burstUntil then
			on = math.random() < 0.45
		end
	end
	spot.Enabled = on
	spill.Enabled = on
	motes.Enabled = on
	spot.Brightness = 3.7 + math.noise(t * 6, 1) * 0.6
	for _, b in ipairs(menuButtons) do
		if t < burstUntil and settings.flicker then
			b.TextTransparency = on and 0 or 0.65
		elseif b.TextTransparency > 0.5 then
			b.TextTransparency = 0
		end
	end
	-- "дыхание" заголовка
	titleHolder.Size = UDim2.fromOffset(640 + math.sin(t * 1.3) * 4, 130 + math.sin(t * 1.3) * 2)
	recDot.BackgroundTransparency = (t % 1 < 0.5) and 0 or 1
	local secs = math.floor(t) % 60
	local mins = (13 + math.floor(t / 60)) % 60
	recLabel.Text = string.format("REC  КАМ-13  03:%02d:%02d", mins, secs)

	-- зерно/царапины/VHS
	grain.Visible = settings.grain
	if settings.grain then
		for _, s in ipairs(scratches) do
			if math.random() < 0.15 then
				s.Position = UDim2.fromScale(math.random(), 0)
				s.BackgroundTransparency = 0.7 + math.random() * 0.3
			end
		end
		for _, d in ipairs(dust) do
			d.Position = UDim2.fromScale(math.random(), math.random())
			d.BackgroundTransparency = 0.4 + math.random() * 0.6
		end
		for i, l in ipairs(vhsLines) do
			l.Position = UDim2.fromScale(0, ((t * (0.08 + i * 0.03)) + i * 0.3) % 1)
			l.BackgroundTransparency = 0.86 + math.noise(t * 3, i) * 0.08
		end
	end
	-- сердце и дыхание нарастают с каждой стадией
	if menuHeart then
		menuHeart.Volume = 0.15 * (stage - 1)
		menuHeart.PlaybackSpeed = 0.9 + stage * 0.1
	end
	if menuBreath then
		menuBreath.Volume = stage >= 3 and 0.5 or 0
	end
end)

-- цикл "блэкаутов": с каждым разом Пациент ближе, в конце — в лицо
local hiddenCF = CFrame.new(0, -500, 0)
local function pointCF(i)
	local p = menuPoints and menuPoints:FindFirstChild("P" .. i)
	return p and p.CFrame
end
if menuMonster then
	menuMonster:PivotTo(pointCF(1) or hiddenCF)
	Animator.track(menuMonster)
	menuMonster:SetAttribute("State", "Patrol")
end
local scenePropState = {}
local function sceneProp(name)
	return menuScene and menuScene:FindFirstChild(name, true)
end
local function slamDoor()
	local door = sceneProp("SlamDoor")
	if door and door:IsA("BasePart") then
		if not scenePropState.door then
			scenePropState.door = door.CFrame
		end
		local hingeValue = door:FindFirstChild("Hinge")
		local h = hingeValue and hingeValue.Value or door.Size.X / 2
		local swung = scenePropState.door * CFrame.new(-h, 0, 0) * CFrame.Angles(0, -1.4, 0) * CFrame.new(h, 0, 0)
		TweenService:Create(door, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = swung }):Play()
		task.delay(0.2, function()
			Sound.play("MetalBang", nil, { Volume = 1 })
		end)
		task.delay(3, function()
			TweenService:Create(door, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { CFrame = scenePropState.door }):Play()
		end)
	end
end
local function rollWheelchair()
	local chair = sceneProp("Wheelchair")
	if chair and chair:IsA("Model") then
		if not scenePropState.chair then
			scenePropState.chair = chair:GetPivot()
		end
		local cf = scenePropState.chair
		local dest = cf * CFrame.new(0, 0, -9)
		task.spawn(function()
			for i = 1, 40 do
				chair:PivotTo(cf:Lerp(dest, i / 40) * CFrame.Angles(0, math.sin(i * 0.3) * 0.03, 0))
				task.wait(0.05)
			end
			task.wait(4)
			chair:PivotTo(cf)
		end)
	end
end
local function swingLamp()
	local lamp = sceneProp("SwingLamp")
	if lamp and lamp:IsA("Model") then
		if not scenePropState.lamp then
			scenePropState.lamp = lamp:GetPivot()
		end
		local cf = scenePropState.lamp
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 6 and inMenu do
				local t = os.clock() - t0
				lamp:PivotTo(cf * CFrame.Angles(0, 0, math.sin(t * 3.2) * 0.35 * math.exp(-t * 0.35)))
				task.wait()
			end
			if lamp.Parent then
				lamp:PivotTo(cf)
			end
		end)
	end
end

task.spawn(function()
	task.wait(4)
	while inMenu do
		task.wait(5 + math.random() * 5)
		if not inMenu then
			break
		end
		blackout = true
		Sound.play("FlashlightOff", nil, { Volume = 0.8 })
		sceneDark.BackgroundTransparency = 0.05
		if stage == 2 then
			rollWheelchair()
		elseif stage == 3 then
			slamDoor()
		end
		task.wait(0.5 + math.random() * 0.7)
		stage = stage % 6 + 1
		if menuMonster then
			local cf = stage <= 4 and pointCF(stage) or nil
			menuMonster:PivotTo(cf or hiddenCF)
			menuMonster:SetAttribute("State", stage >= 3 and "Chase" or "Patrol")
		end
		if not inMenu then
			break
		end
		Sound.play("FlashlightOn", nil, { Volume = 0.8 })
		blackout = false
		sceneDark.BackgroundTransparency = 1
		burstUntil = os.clock() + 0.35
		if stage == 3 then
			swingLamp()
			Sound.play("Whisper", nil, { Volume = 1 })
		elseif stage == 4 then
			-- оно уже рядом: красные вспышки, шёпот
			Sound.play("Whisper", nil, { Volume = 1 })
			Sound.play("Static", nil, { Volume = 0.35 })
			camShake = 1
			for _ = 1, 6 do
				sceneDark.BackgroundColor3 = Color3.fromRGB(90, 0, 0)
				sceneDark.BackgroundTransparency = 0.7 + math.random() * 0.25
				task.wait(0.05)
			end
			sceneDark.BackgroundColor3 = Color3.new(0, 0, 0)
			sceneDark.BackgroundTransparency = 1
		elseif stage == 5 then
			-- В ЛИЦО: Пациент перед самой камерой, крик, помехи, "ОНО ВИДИТ ТЕБЯ"
			if menuMonster then
				local cam = workspace.CurrentCamera
				local facePos = cam.CFrame.Position + cam.CFrame.LookVector * 3.2 - Vector3.new(0, 7.2, 0)
				menuMonster:PivotTo(CFrame.lookAt(facePos, Vector3.new(cam.CFrame.Position.X, facePos.Y, cam.CFrame.Position.Z)))
				menuMonster:SetAttribute("State", "Attack")
			end
			Sound.play("MonsterScream", nil, { Volume = 1.6 })
			Sound.play("Static", nil, { Volume = 1 })
			camShake = 3
			camPush = 1.2
			warnText.Text = "ОНО ВИДИТ ТЕБЯ"
			for i = 1, 14 do
				warnText.TextTransparency = (i % 2 == 0) and 0 or 0.6
				warnText.Position = UDim2.fromOffset(math.random(-8, 8), math.random(-5, 5))
				sceneDark.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(120, 0, 0) or Color3.new(0, 0, 0)
				sceneDark.BackgroundTransparency = 0.55 + math.random() * 0.3
				task.wait(0.06)
			end
			task.wait(0.6)
			blackout = true
			sceneDark.BackgroundColor3 = Color3.new(0, 0, 0)
			sceneDark.BackgroundTransparency = 0
			warnText.Text = "СИГНАЛ ПОТЕРЯН"
			warnText.TextColor3 = Colors.Dim
			task.wait(1.6)
			UI.tween(warnText, 0.5, { TextTransparency = 1 })
			warnText.TextColor3 = Colors.BrightRed
			if menuMonster then
				menuMonster:PivotTo(hiddenCF)
				menuMonster:SetAttribute("State", "Patrol")
			end
			task.wait(0.8)
			blackout = false
			sceneDark.BackgroundTransparency = 1
			stage = 6
		elseif stage == 6 then
			Sound.play("MetalBang", nil, { Volume = 0.6 })
			stage = 0 -- следующий блэкаут вернёт Пациента в начало коридора
		end
	end
end)

-- ============================ HUD ЛОББИ ============================
local hud = UI.new("Frame", {
	Name = "HUD",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 2,
	Parent = gui,
})
UI.vignette(hud, 0.35)
local coinsLabel = UI.label({
	Text = "🪙 0",
	Font = UI.FontTitle,
	TextSize = 26,
	TextColor3 = Colors.Gold,
	Size = UDim2.fromOffset(260, 30),
	Position = UDim2.fromOffset(20, 58),
	TextStrokeTransparency = 0.5,
	Parent = hud,
})
local levelLabel = UI.label({
	Text = "УРОВЕНЬ 1",
	Font = UI.FontMono,
	TextSize = 14,
	TextColor3 = Colors.Text,
	Size = UDim2.fromOffset(260, 18),
	Position = UDim2.fromOffset(20, 92),
	TextStrokeTransparency = 0.6,
	Parent = hud,
})
local xpBack = UI.new("Frame", {
	Size = UDim2.fromOffset(220, 6),
	Position = UDim2.fromOffset(20, 114),
	BackgroundColor3 = Color3.fromRGB(25, 12, 12),
	BorderSizePixel = 0,
	Parent = hud,
}, { UI.stroke(Colors.Red, 1, 0.6) })
local xpFill = UI.new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Colors.Red,
	BorderSizePixel = 0,
	Parent = xpBack,
})
UI.label({
	Text = "F — фонарик  ·  E — киоски и пульт врат  ·  встань в круг у врат, чтобы отправиться",
	Font = UI.FontMono,
	TextSize = 13,
	TextColor3 = Colors.Dim,
	TextTransparency = 0.3,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromOffset(760, 18),
	Position = UDim2.new(0.5, 0, 1, -14),
	AnchorPoint = Vector2.new(0.5, 1),
	Parent = hud,
})

local sideButtons = UI.new("Frame", {
	Size = UDim2.fromOffset(190, 260),
	Position = UDim2.new(1, -20, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	BackgroundTransparency = 1,
	Parent = hud,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local gatePanel = UI.new("Frame", {
	Size = UDim2.fromOffset(640, 96),
	Position = UDim2.new(0.5, 0, 1, -40),
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundColor3 = Colors.Panel,
	BackgroundTransparency = 0.15,
	Visible = false,
	Parent = hud,
}, { UI.corner(4), UI.stroke(Colors.Red, 1, 0.3) })
local gateTitle = UI.label({
	Text = "",
	Font = UI.FontTitle,
	TextSize = 24,
	TextColor3 = Colors.BrightRed,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, -150, 0, 34),
	Position = UDim2.fromOffset(0, 6),
	Parent = gatePanel,
})
local gateSub = UI.label({
	Text = "",
	Font = UI.FontMono,
	TextSize = 14,
	TextColor3 = Colors.Dim,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, -150, 0, 18),
	Position = UDim2.fromOffset(0, 44),
	Parent = gatePanel,
})
UI.label({
	Text = "выйди из круга, чтобы покинуть очередь",
	Font = UI.FontMono,
	TextSize = 12,
	TextColor3 = Colors.Dim,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, -150, 0, 16),
	Position = UDim2.fromOffset(0, 66),
	Parent = gatePanel,
})

-- ============================ ОКНА ============================
local windows = {}
local function openWindow(w)
	for _, other in ipairs(windows) do
		if other ~= w and other.frame.Visible then
			other.close()
		end
	end
	w.open()
end

local function promptPass(key)
	local id = Config.GamePasses[key]
	if not id or id == 0 then
		toast("Геймпасс «" .. key .. "» не настроен (ID = 0 в Config)", Colors.Red)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, id)
end
local function promptProduct(key)
	local id = Config.Products[key]
	if not id or id == 0 then
		toast("Продукт «" .. key .. "» не настроен (ID = 0 в Config)", Colors.Red)
		return
	end
	MarketplaceService:PromptProductPurchase(player, id)
end

local priceCache = {}
local function fetchPrice(kind, id, label)
	if not id or id == 0 then
		label.Text = "не настроено"
		return
	end
	local cacheKey = kind .. tostring(id)
	if priceCache[cacheKey] then
		label.Text = priceCache[cacheKey]
		return
	end
	label.Text = "..."
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, kind == "pass" and Enum.InfoType.GamePass or Enum.InfoType.Product)
		end)
		local text = (ok and info and info.PriceInRobux) and ("R$ " .. tostring(info.PriceInRobux)) or "R$ ?"
		priceCache[cacheKey] = text
		if label.Parent then
			label.Text = text
		end
	end)
end

local function clearChildren(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

-- ---------- МАГАЗИН (касса / фонари / аптека / регистратура) ----------
local shopWin = UI.window(gui, "МАГАЗИН", UDim2.new(0.86, 0, 0.84, 0))
table.insert(windows, shopWin)
local shopCoins = UI.label({
	Text = "",
	Font = UI.FontTitle,
	TextSize = 22,
	TextColor3 = Colors.Gold,
	TextXAlignment = Enum.TextXAlignment.Right,
	Size = UDim2.fromOffset(250, 40),
	Position = UDim2.new(1, -250, 0, 0),
	ZIndex = 22,
	Parent = shopWin.content,
})
local shopScroll = UI.new("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -52),
	Position = UDim2.fromOffset(0, 52),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Colors.Red,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 22,
	Parent = shopWin.content,
}, {
	UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(220, 214),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local currentTab = "robux"
local renderShop
local SHOP_TITLES = { robux = "КАССА · ЗА РОБУКСЫ", lights = "ЛАВКА ФОНАРЕЙ", perks = "АПТЕКА · ПЕРКИ", titles = "РЕГИСТРАТУРА · ТИТУЛЫ" }
local shopTabs = UI.tabs(shopWin.content, {
	{ id = "robux", text = "РОБУКСЫ" },
	{ id = "lights", text = "ФОНАРИКИ" },
	{ id = "perks", text = "ПЕРКИ" },
	{ id = "titles", text = "ТИТУЛЫ" },
}, currentTab, function(id)
	currentTab = id
	renderShop()
end, { Size = UDim2.new(1, -260, 0, 40), Width = 140, ZIndex = 22 })

local function card(order)
	return UI.new("Frame", {
		BackgroundColor3 = Colors.Panel2,
		BackgroundTransparency = 0.05,
		LayoutOrder = order,
		ZIndex = 23,
		Parent = shopScroll,
	}, { UI.corner(4), UI.stroke(Colors.Red, 1, 0.55), UI.padding(10) })
end

local function cardText(parent, props)
	props.Parent = parent
	props.ZIndex = 24
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
	return UI.label(props)
end

local function cardButton(c, text, color, onClick)
	return UI.button({
		Text = text,
		TextSize = 18,
		TextColor3 = color or Colors.Text,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 1, -30),
		ZIndex = 24,
		Parent = c,
	}, onClick)
end

local function shopAction(action, arg)
	local ok, text = Remotes.ShopRequest:InvokeServer(action, arg)
	toast(text or "", ok and Colors.Green or Colors.Red)
	if ok and (action == "buyFlashlight" or action == "buyPerk") then
		Sound.play("Purchase", nil, { Volume = 0.8 })
	end
end

renderShop = function()
	local d = ClientData.get() or {}
	local passes = d.passes or {}
	shopCoins.Text = "🪙 " .. tostring(d.coins or 0)
	shopWin.title.Text = SHOP_TITLES[currentTab] or "МАГАЗИН"
	shopTabs.select(currentTab)
	clearChildren(shopScroll)

	if currentTab == "robux" then
		for i, item in ipairs(Config.ShopRobux) do
			local c = card(i)
			local id = item.kind == "pass" and Config.GamePasses[item.key] or Config.Products[item.key]
			cardText(c, { Text = item.icon, TextSize = 40, Size = UDim2.new(1, 0, 0, 50) })
			cardText(c, { Text = item.name, Font = UI.FontTitle, TextSize = 19, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 52) })
			cardText(c, { Text = item.desc, TextSize = 14, TextColor3 = Colors.Dim, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 78), TextYAlignment = Enum.TextYAlignment.Top })
			local price = cardText(c, { Text = "", Font = UI.FontMono, TextSize = 15, TextColor3 = Colors.Gold, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 138) })
			local owned = item.kind == "pass" and passes[item.key]
			if owned then
				price.Text = "уже твоё"
			else
				fetchPrice(item.kind, id, price)
			end
			cardButton(c, owned and "✓ КУПЛЕНО" or "КУПИТЬ", owned and Colors.Green or Colors.Text, function()
				if owned then
					return
				end
				if item.kind == "pass" then
					promptPass(item.key)
				else
					promptProduct(item.key)
				end
			end)
		end
	elseif currentTab == "lights" then
		local owned = d.flashlights or {}
		for i, f in ipairs(Config.Flashlights) do
			local c = card(i)
			local swatch = UI.new("Frame", {
				Size = UDim2.fromOffset(52, 52),
				Position = UDim2.new(0.5, 0, 0, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = f.color,
				ZIndex = 24,
				Parent = c,
			}, { UI.corner(26), UI.stroke(f.color, 3, 0.4) })
			UI.new("UIGradient", {
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) }),
				Rotation = 90,
				Parent = swatch,
			})
			cardText(c, { Text = f.name, Font = UI.FontTitle, TextSize = 20, TextColor3 = f.color, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 62) })
			local info
			if f.source == "bp" then
				info = "только из батлпасса"
			elseif f.price > 0 then
				info = "🪙 " .. f.price
			else
				info = "бесплатно"
			end
			cardText(c, { Text = info, Font = UI.FontMono, TextSize = 15, TextColor3 = Colors.Gold, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 96) })
			local isOwned = owned[f.id] == true
			local equipped = d.flashlight == f.id
			local text = equipped and "✓ В РУКАХ" or (isOwned and "ВЗЯТЬ" or (f.source == "bp" and "🔒 ЗАКРЫТО" or "КУПИТЬ"))
			cardButton(c, text, equipped and Colors.Green or Colors.Text, function()
				if equipped then
					return
				elseif isOwned then
					shopAction("equipFlashlight", f.id)
				elseif f.source == "bp" then
					toast("Этот фонарик можно получить только в батлпассе", Colors.Dim)
				else
					shopAction("buyFlashlight", f.id)
				end
			end)
		end
	elseif currentTab == "perks" then
		local owned = d.perks or {}
		for i, p in ipairs(Config.Perks) do
			local c = card(i)
			cardText(c, { Text = p.icon, TextSize = 40, Size = UDim2.new(1, 0, 0, 50) })
			cardText(c, { Text = p.name, Font = UI.FontTitle, TextSize = 18, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 52) })
			cardText(c, { Text = p.desc, TextSize = 14, TextColor3 = Colors.Dim, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 78), TextYAlignment = Enum.TextYAlignment.Top })
			local has = owned[p.id] == true and not p.consumable
			local priceText = has and "действует всегда" or ("🪙 " .. p.price .. (p.consumable and ("   ·   у тебя: " .. (d.revives or 0)) or ""))
			cardText(c, { Text = priceText, Font = UI.FontMono, TextSize = 14, TextColor3 = Colors.Gold, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 138) })
			cardButton(c, has and "✓ КУПЛЕНО" or "КУПИТЬ", has and Colors.Green or Colors.Text, function()
				if has then
					return
				end
				shopAction("buyPerk", p.id)
			end)
		end
	else
		local titles = d.titles or {}
		for i, t in ipairs(Config.Titles) do
			local c = card(i)
			cardText(c, { Text = "🏷", TextSize = 34, Size = UDim2.new(1, 0, 0, 44) })
			cardText(c, { Text = "«" .. t.name .. "»", Font = UI.FontTitle, TextSize = 20, TextColor3 = t.color, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 50) })
			local has = titles[t.id] == true or (t.id == "VIP" and passes.VIP)
			local src
			if t.id == "VIP" then
				src = "геймпасс VIP"
			elseif t.id == "Newbie" then
				src = "есть у всех"
			elseif t.source and string.sub(t.source, 1, 4) == "map:" then
				src = "побег: " .. Config.getMap(string.sub(t.source, 5)).name
			elseif t.source == "nightmare" then
				src = "побег на сложности КОШМАР"
			else
				src = "награда батлпасса"
			end
			cardText(c, { Text = src, Font = UI.FontMono, TextSize = 13, TextColor3 = Colors.Dim, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 108) })
			local selected = d.title == t.id
			cardButton(c, selected and "✓ ВЫБРАН" or (has and "НАДЕТЬ" or "🔒 НЕ ПОЛУЧЕН"), selected and Colors.Green or Colors.Text, function()
				if selected then
					return
				end
				if has then
					shopAction("equipTitle", t.id)
				elseif t.id == "VIP" then
					promptPass("VIP")
				else
					toast("Титул выдаётся за: " .. src, Colors.Dim)
				end
			end)
		end
	end
end

-- ---------- БАТЛПАСС ----------
local bpWin = UI.window(gui, "БАТЛПАСС · " .. BattlePass.SeasonName, UDim2.new(0.9, 0, 0.84, 0))
table.insert(windows, bpWin)
local bpLevel = UI.label({
	Text = "",
	Font = UI.FontTitle,
	TextSize = 24,
	Size = UDim2.new(0.5, 0, 0, 28),
	ZIndex = 22,
	Parent = bpWin.content,
})
local bpBack = UI.new("Frame", {
	Size = UDim2.new(0.42, 0, 0, 10),
	Position = UDim2.fromOffset(0, 34),
	BackgroundColor3 = Color3.fromRGB(25, 12, 12),
	BorderSizePixel = 0,
	ZIndex = 22,
	Parent = bpWin.content,
}, { UI.stroke(Colors.Red, 1, 0.5) })
local bpFill = UI.new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Colors.Red,
	BorderSizePixel = 0,
	ZIndex = 23,
	Parent = bpBack,
})
local bpXP = UI.label({
	Text = "",
	Font = UI.FontMono,
	TextSize = 13,
	TextColor3 = Colors.Dim,
	Size = UDim2.new(0.5, 0, 0, 16),
	Position = UDim2.fromOffset(0, 50),
	ZIndex = 22,
	Parent = bpWin.content,
})
local buyPremium = UI.button({
	Text = "🩸 КУПИТЬ ПРЕМИУМ",
	TextSize = 17,
	TextColor3 = Colors.Gold,
	Size = UDim2.fromOffset(230, 40),
	Position = UDim2.new(1, -470, 0, 6),
	ZIndex = 22,
	Parent = bpWin.content,
}, function()
	promptPass("PremiumPass")
end)
UI.button({
	Text = "⏭ +1 УРОВЕНЬ",
	TextSize = 17,
	Size = UDim2.fromOffset(230, 40),
	Position = UDim2.new(1, -230, 0, 6),
	ZIndex = 22,
	Parent = bpWin.content,
}, function()
	promptProduct("SkipTier")
end)
UI.label({
	Text = "БЕСПЛАТНО",
	Font = UI.FontBold,
	TextSize = 14,
	TextColor3 = Colors.Text,
	Size = UDim2.new(0, 86, 0.5, -60),
	Position = UDim2.fromOffset(0, 104),
	ZIndex = 22,
	Parent = bpWin.content,
})
UI.label({
	Text = "ПРЕМИУМ",
	Font = UI.FontBold,
	TextSize = 14,
	TextColor3 = Colors.Gold,
	Size = UDim2.new(0, 86, 0.5, -60),
	Position = UDim2.new(0, 0, 0.5, 46),
	ZIndex = 22,
	Parent = bpWin.content,
})
local bpScroll = UI.new("ScrollingFrame", {
	Size = UDim2.new(1, -92, 1, -78),
	Position = UDim2.fromOffset(92, 78),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Colors.Red,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	ZIndex = 22,
	Parent = bpWin.content,
}, {
	UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function rewardCard(col, tier, track, reward, d)
	local premium = track == "premium"
	local k = tostring(tier)
	local claimed = d.bpClaimed and d.bpClaimed[track] and d.bpClaimed[track][k]
	local unlocked = (d.tier or 0) >= tier
	local owned = (not premium) or (d.passes and d.passes.PremiumPass)
	local f = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0.5, -24),
		Position = premium and UDim2.new(0, 0, 0.5, 8) or UDim2.fromOffset(0, 28),
		BackgroundColor3 = premium and Color3.fromRGB(48, 10, 12) or Colors.Panel2,
		BackgroundTransparency = unlocked and 0 or 0.45,
		ZIndex = 23,
		Parent = col,
	}, { UI.corner(4), UI.stroke(premium and Colors.Gold or Colors.Red, 1, unlocked and 0.25 or 0.7) })
	if not reward then
		return
	end
	local color = Colors.Text
	if reward.type == "flashlight" then
		color = Config.getFlashlight(reward.id).color
	elseif reward.type == "title" then
		local t = Config.getTitle(reward.id)
		color = t and t.color or color
	end
	UI.label({
		Text = BattlePass.icon(reward),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0.36, 0),
		TextTransparency = unlocked and 0 or 0.4,
		ZIndex = 24,
		Parent = f,
	})
	UI.label({
		Text = BattlePass.describe(reward),
		TextSize = 13,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -8, 0.3, 0),
		Position = UDim2.new(0, 4, 0.36, 0),
		TextTransparency = unlocked and 0 or 0.4,
		ZIndex = 24,
		Parent = f,
	})
	local text
	if claimed then
		text = "✓"
	elseif not owned then
		text = "🩸"
	elseif not unlocked then
		text = "🔒"
	else
		text = "ЗАБРАТЬ"
	end
	UI.button({
		Text = text,
		TextSize = 15,
		TextColor3 = claimed and Colors.Green or (text == "ЗАБРАТЬ" and Colors.Gold or Colors.Dim),
		Size = UDim2.new(1, -10, 0, 26),
		Position = UDim2.new(0, 5, 1, -31),
		ZIndex = 24,
		Parent = f,
	}, function()
		if claimed then
			return
		end
		if not owned then
			promptPass("PremiumPass")
			return
		end
		if not unlocked then
			toast("Нужен уровень " .. tier .. ". Играй раунды, чтобы получать опыт.", Colors.Dim)
			return
		end
		local ok, msgText = Remotes.ClaimReward:InvokeServer(tier, track)
		toast(msgText or "", ok and Colors.Green or Colors.Red)
		if ok then
			Sound.play("Purchase", nil, { Volume = 0.8 })
		end
	end)
end

local function renderBP(scrollToCurrent)
	local d = ClientData.get() or {}
	local xp = d.xp or 0
	local tier, frac = BattlePass.progress(xp)
	d.tier = d.tier or tier
	bpLevel.Text = string.format("УРОВЕНЬ %d / %d", tier, BattlePass.MaxTier)
	bpFill.Size = UDim2.fromScale(tier >= BattlePass.MaxTier and 1 or frac, 1)
	bpXP.Text = tier >= BattlePass.MaxTier and "сезон пройден полностью" or string.format("%d / %d XP до следующего уровня", math.floor(frac * BattlePass.XPPerTier), BattlePass.XPPerTier)
	local premiumOwned = d.passes and d.passes.PremiumPass
	buyPremium.Text = premiumOwned and "✓ ПРЕМИУМ АКТИВЕН" or "🩸 КУПИТЬ ПРЕМИУМ"
	clearChildren(bpScroll)
	for t = 1, BattlePass.MaxTier do
		local col = UI.new("Frame", {
			Size = UDim2.new(0, 124, 1, -12),
			BackgroundTransparency = 1,
			LayoutOrder = t,
			ZIndex = 23,
			Parent = bpScroll,
		})
		UI.label({
			Text = (t == tier) and ("▶ " .. t) or tostring(t),
			Font = UI.FontTitle,
			TextSize = 20,
			TextColor3 = (t <= tier) and Colors.BrightRed or Colors.Dim,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 24),
			ZIndex = 24,
			Parent = col,
		})
		local row = BattlePass.Tiers[t] or {}
		rewardCard(col, t, "free", row.free, d)
		rewardCard(col, t, "premium", row.premium, d)
	end
	if scrollToCurrent then
		task.defer(function()
			bpScroll.CanvasPosition = Vector2.new(math.max(0, (tier - 2) * 132), 0)
		end)
	end
end

-- ---------- КАРТЫ И СЛОЖНОСТЬ ----------
local mapsWin = UI.window(gui, "КАРТЫ · ИСТОРИИ · СЛОЖНОСТЬ", UDim2.new(0.9, 0, 0.86, 0))
table.insert(windows, mapsWin)
local mapsScroll = UI.new("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Colors.Red,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 22,
	Parent = mapsWin.content,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
local function renderMaps()
	clearChildren(mapsScroll)
	local d = ClientData.get() or {}
	local escaped = (d.stats and d.stats.mapsEscaped) or {}
	for i, m in ipairs(Config.Maps) do
		local row = UI.new("Frame", {
			Size = UDim2.new(1, -8, 0, 150),
			BackgroundColor3 = Colors.Panel2,
			BackgroundTransparency = 0.05,
			LayoutOrder = i,
			ZIndex = 23,
			Parent = mapsScroll,
		}, { UI.corner(4), UI.stroke(m.color or Colors.Red, 1, 0.4), UI.padding(12) })
		UI.label({ Text = m.icon .. "  " .. m.name, Font = UI.FontTitle, TextSize = 26, TextColor3 = m.color, Size = UDim2.new(0.6, 0, 0, 30), ZIndex = 24, Parent = row })
		UI.label({ Text = m.subtitle, Font = UI.FontMono, TextSize = 13, TextColor3 = Colors.Dim, Size = UDim2.new(0.6, 0, 0, 16), Position = UDim2.fromOffset(0, 30), ZIndex = 24, Parent = row })
		UI.label({ Text = m.story, TextSize = 15, TextColor3 = Colors.Text, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 50), ZIndex = 24, Parent = row })
		UI.label({ Text = "ЦЕЛЬ: " .. m.goal, Font = UI.FontBold, TextSize = 14, TextColor3 = Colors.Gold, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 106), ZIndex = 24, Parent = row })
		UI.label({
			Text = string.format("генераторов: %d   ·   побегов: %d", m.generators, escaped[m.id] or 0),
			Font = UI.FontMono,
			TextSize = 13,
			TextColor3 = Colors.Dim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(0.4, 0, 0, 16),
			Position = UDim2.new(0.6, 0, 0, 8),
			ZIndex = 24,
			Parent = row,
		})
	end
	local drow = UI.new("Frame", {
		Size = UDim2.new(1, -8, 0, 40 + #Config.Difficulties * 58),
		BackgroundColor3 = Colors.Panel2,
		BackgroundTransparency = 0.05,
		LayoutOrder = 10,
		ZIndex = 23,
		Parent = mapsScroll,
	}, { UI.corner(4), UI.stroke(Colors.Red, 1, 0.4), UI.padding(12) })
	UI.label({ Text = "СЛОЖНОСТЬ — выбирается на пульте у врат", Font = UI.FontTitle, TextSize = 22, Size = UDim2.new(1, 0, 0, 28), ZIndex = 24, Parent = drow })
	for i, df in ipairs(Config.Difficulties) do
		local y = 34 + (i - 1) * 58
		UI.label({ Text = df.icon .. "  " .. df.name, Font = UI.FontTitle, TextSize = 19, TextColor3 = df.color, Size = UDim2.new(0.25, 0, 0, 24), Position = UDim2.fromOffset(0, y), ZIndex = 24, Parent = drow })
		UI.label({ Text = (df.blind and "СЛЕПОЕ, СЛЫШИТ" or "ВИДИТ И СЛЫШИТ") .. string.format("  ·  награды x%.1f", df.coinMult), Font = UI.FontMono, TextSize = 12, TextColor3 = Colors.Dim, Size = UDim2.new(0.25, 0, 0, 16), Position = UDim2.fromOffset(0, y + 24), ZIndex = 24, Parent = drow })
		UI.label({ Text = df.desc, TextSize = 14, TextColor3 = Colors.Text, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(0.74, 0, 0, 52), Position = UDim2.new(0.26, 0, 0, y), ZIndex = 24, Parent = drow })
	end
end

-- ---------- ПРОФИЛЬ ----------
local profWin = UI.window(gui, "ПРОФИЛЬ", UDim2.fromOffset(560, 420))
table.insert(windows, profWin)
local profText = UI.label({
	Text = "",
	Font = UI.FontMono,
	TextSize = 16,
	TextColor3 = Colors.Text,
	TextYAlignment = Enum.TextYAlignment.Top,
	Size = UDim2.new(1, 0, 1, 0),
	ZIndex = 22,
	Parent = profWin.content,
})
local function renderProfile()
	local d = ClientData.get() or {}
	local s = d.stats or {}
	local tier = BattlePass.tierFromXP(d.xp or 0)
	local perks = {}
	for _, p in ipairs(Config.Perks) do
		if d.perks and d.perks[p.id] then
			table.insert(perks, p.name)
		end
	end
	local maps = {}
	for _, m in ipairs(Config.Maps) do
		table.insert(maps, string.format("  %s %s: %d", m.icon, m.name, (s.mapsEscaped and s.mapsEscaped[m.id]) or 0))
	end
	local t = Config.getTitle(d.title) or Config.getTitle("Newbie")
	profText.Text = string.format(
		"%s   ·   титул: «%s»\nуровень батлпасса: %d   ·   монет: %d\n\nраундов: %d   побегов: %d   смертей: %d\nгенераторов починено: %d\nпобегов на КОШМАРЕ: %d\n\nПОБЕГИ ПО КАРТАМ:\n%s\n\nПЕРКИ: %s\nжетонов возрождения: %d",
		player.DisplayName,
		t and t.name or "",
		tier,
		d.coins or 0,
		s.games or 0,
		s.escapes or 0,
		s.deaths or 0,
		s.generators or 0,
		s.nightmareEscapes or 0,
		table.concat(maps, "\n"),
		#perks > 0 and table.concat(perks, ", ") or "—",
		d.revives or 0
	)
end

-- ---------- НАСТРОЙКИ ----------
local setWin = UI.window(gui, "НАСТРОЙКИ", UDim2.fromOffset(560, 470))
table.insert(windows, setWin)
local setList = UI.new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 22,
	Parent = setWin.content,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
local function settingRow(order, labelText)
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 22, Parent = setList })
	UI.label({ Text = labelText, Font = UI.FontBold, TextSize = 17, Size = UDim2.new(0.42, 0, 1, 0), ZIndex = 22, Parent = row })
	return row
end
local sliders = {}
for i, s in ipairs({ { "master", "ОБЩАЯ ГРОМКОСТЬ" }, { "music", "МУЗЫКА И АТМОСФЕРА" }, { "sfx", "ЭФФЕКТЫ" } }) do
	local row = settingRow(i, s[2])
	sliders[s[1]] = UI.slider({ Size = UDim2.new(0.56, 0, 1, 0), Position = UDim2.new(0.44, 0, 0, 0), ZIndex = 23, Parent = row }, settings[s[1]] or 1, function(v)
		settings[s[1]] = v
		applySettings()
		saveSettings()
	end)
end
local sensRow = settingRow(4, "ЧУВСТВИТЕЛЬНОСТЬ МЫШИ")
sliders.sensitivity = UI.slider({ Size = UDim2.new(0.56, 0, 1, 0), Position = UDim2.new(0.44, 0, 0, 0), ZIndex = 23, Parent = sensRow }, (settings.sensitivity or 1) / 3, function(v)
	settings.sensitivity = math.max(0.2, v * 3)
	applySettings()
	saveSettings()
end)
local refreshSettings
local function toggleRow(order, labelText, key, onText, offText)
	local row = settingRow(order, labelText)
	local btn = UI.button({ Text = "", TextSize = 15, Size = UDim2.fromOffset(200, 36), Position = UDim2.new(1, -200, 0, 2), ZIndex = 23, Parent = row }, function()
		settings[key] = not settings[key]
		saveSettings()
		refreshSettings()
	end)
	return function()
		btn.Text = settings[key] and onText or offText
	end
end
local toggles = {
	toggleRow(5, "ЗЕРНО И ЦАРАПИНЫ", "grain", "ВКЛ", "ВЫКЛ"),
	toggleRow(6, "МЕРЦАНИЕ СВЕТА В МЕНЮ", "flicker", "ВКЛ", "ВЫКЛ"),
	toggleRow(7, "ПРИСЯДКА (C)", "crouchToggle", "ПЕРЕКЛЮЧЕНИЕ", "УДЕРЖАНИЕ"),
}
UI.label({
	Text = "Настройки сохраняются в профиле и действуют в больнице.",
	Font = UI.FontMono,
	TextSize = 13,
	TextColor3 = Colors.Dim,
	Size = UDim2.new(1, 0, 0, 20),
	LayoutOrder = 8,
	ZIndex = 22,
	Parent = setList,
})
refreshSettings = function()
	for k, s in pairs(sliders) do
		if k == "sensitivity" then
			s.set((settings.sensitivity or 1) / 3)
		else
			s.set(settings[k] or 1)
		end
	end
	for _, f in ipairs(toggles) do
		f()
	end
end
refreshSettings()

-- ---------- ПУЛЬТ ВРАТ ----------
local GatesFolder = Lobby:WaitForChild("Gates")
local ROMAN = { "I", "II", "III", "IV", "V" }
local gateWin = UI.window(gui, "ПУЛЬТ ВРАТ", UDim2.fromOffset(820, 560))
table.insert(windows, gateWin)
local gateCfg = { gate = "Gate1", map = "Hospital", difficulty = "Medium", maxPlayers = Config.MaxPlayersPerRound }
UI.label({ Text = "КАРТА", Font = UI.FontTitle, TextSize = 18, TextColor3 = Colors.Dim, Size = UDim2.new(1, 0, 0, 22), ZIndex = 22, Parent = gateWin.content })
local mapChoice = UI.new("Frame", {
	Size = UDim2.new(1, 0, 0, 150),
	Position = UDim2.fromOffset(0, 24),
	BackgroundTransparency = 1,
	ZIndex = 22,
	Parent = gateWin.content,
}, { UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
local mapCards = {}
local function paintMapCards()
	for id, c in pairs(mapCards) do
		local on = id == gateCfg.map
		c.frame.BackgroundTransparency = on and 0 or 0.5
		c.stroke.Transparency = on and 0 or 0.7
		c.stroke.Thickness = on and 2 or 1
	end
end
for i, m in ipairs(Config.Maps) do
	local f = UI.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1 / #Config.Maps, -6, 1, 0),
		BackgroundColor3 = Colors.Panel2,
		LayoutOrder = i,
		ZIndex = 23,
		Parent = mapChoice,
	}, { UI.corner(4), UI.padding(8) })
	local stroke = UI.stroke(m.color, 1, 0.7)
	stroke.Parent = f
	UI.label({ Text = m.icon .. "  " .. m.name, Font = UI.FontTitle, TextSize = 20, TextColor3 = m.color, Size = UDim2.new(1, 0, 0, 26), ZIndex = 24, Parent = f })
	UI.label({ Text = m.subtitle, Font = UI.FontMono, TextSize = 12, TextColor3 = Colors.Dim, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 26), ZIndex = 24, Parent = f })
	UI.label({ Text = m.goal, TextSize = 13, TextColor3 = Colors.Text, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromOffset(0, 46), ZIndex = 24, Parent = f })
	f.Activated:Connect(function()
		gateCfg.map = m.id
		Sound.play("UIClick", nil, { Volume = 0.7 })
		paintMapCards()
	end)
	mapCards[m.id] = { frame = f, stroke = stroke }
end
UI.label({ Text = "СЛОЖНОСТЬ", Font = UI.FontTitle, TextSize = 18, TextColor3 = Colors.Dim, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 184), ZIndex = 22, Parent = gateWin.content })
local diffOptions = {}
for _, d in ipairs(Config.Difficulties) do
	table.insert(diffOptions, { id = d.id, text = d.icon .. " " .. d.name, color = d.color })
end
local diffDesc = UI.label({ Text = "", Font = UI.FontMono, TextSize = 13, TextColor3 = Colors.Dim, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 256), ZIndex = 22, Parent = gateWin.content })
local function showDiffDesc()
	local d = Config.getDifficulty(gateCfg.difficulty)
	diffDesc.Text = d.desc
	diffDesc.TextColor3 = d.color
end
local diffChoice = UI.choice(gateWin.content, diffOptions, gateCfg.difficulty, function(id)
	gateCfg.difficulty = id
	showDiffDesc()
end, { Position = UDim2.fromOffset(0, 208), Width = 150, Height = 42, ZIndex = 22 })
UI.label({ Text = "ИГРОКОВ В РАУНДЕ (врата отправят группу, когда соберётся столько или по таймеру)", Font = UI.FontTitle, TextSize = 18, TextColor3 = Colors.Dim, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 300), ZIndex = 22, Parent = gateWin.content })
local playerOptions = {}
for n = 1, Config.MaxPlayersPerRound do
	table.insert(playerOptions, { id = n, text = tostring(n) .. (n == 1 and " (соло)" or "") })
end
local playersChoice = UI.choice(gateWin.content, playerOptions, gateCfg.maxPlayers, function(id)
	gateCfg.maxPlayers = id
end, { Position = UDim2.fromOffset(0, 324), Width = 110, Height = 42, ZIndex = 22 })
local gateStatus = UI.label({ Text = "", Font = UI.FontMono, TextSize = 14, TextColor3 = Colors.Dim, Size = UDim2.new(1, -240, 0, 40), Position = UDim2.new(0, 0, 1, -44), ZIndex = 22, Parent = gateWin.content })
UI.button({
	Text = "ПРИМЕНИТЬ К ВРАТАМ",
	TextSize = 18,
	TextColor3 = Colors.Gold,
	Size = UDim2.fromOffset(230, 44),
	Position = UDim2.new(1, -230, 1, -48),
	ZIndex = 22,
	Parent = gateWin.content,
}, function()
	local ok, text = Remotes.Gate:InvokeServer(gateCfg.gate, { map = gateCfg.map, difficulty = gateCfg.difficulty, maxPlayers = gateCfg.maxPlayers })
	toast(text or "", ok and Colors.Green or Colors.Red)
	if ok then
		gateWin.close()
	end
end)
local function openGate(gateName)
	local m = GatesFolder:FindFirstChild(gateName)
	if not m then
		return
	end
	gateCfg.gate = gateName
	gateCfg.map = m:GetAttribute("Map") or gateCfg.map
	gateCfg.difficulty = m:GetAttribute("Difficulty") or gateCfg.difficulty
	gateCfg.maxPlayers = m:GetAttribute("Max") or gateCfg.maxPlayers
	local n = tonumber(string.match(gateName, "%d+") or "") or 1
	gateWin.title.Text = "ПУЛЬТ ВРАТ " .. (ROMAN[n] or n)
	gateStatus.Text = "Настройки видят все, кто стоит у этих врат. Последний изменивший — прав."
	paintMapCards()
	diffChoice.select(gateCfg.difficulty)
	playersChoice.select(gateCfg.maxPlayers)
	showDiffDesc()
	openWindow(gateWin)
end

local function openShop(tab)
	if tab then
		currentTab = tab
	end
	renderShop()
	openWindow(shopWin)
end
local function openBP()
	renderBP(true)
	openWindow(bpWin)
end
local function openMaps()
	renderMaps()
	openWindow(mapsWin)
end
local function openProfile()
	renderProfile()
	openWindow(profWin)
end
local function openSettings()
	refreshSettings()
	openWindow(setWin)
end

-- ============================ ИГРАТЬ ============================
local function play()
	if not inMenu then
		return
	end
	for _, w in ipairs(windows) do
		if w.frame.Visible then
			w.close()
		end
	end
	fadeText.Text = ""
	fadeTo(0, 0.5)
	Sound.play("FlashlightOff", nil, { Volume = 0.8 })
	task.wait(0.6)
	inMenu = false
	if menuConn then
		menuConn:Disconnect()
	end
	stopTitle()
	menu.Visible = false
	menuLight:Destroy()
	if menuHeart then
		menuHeart:Destroy()
	end
	if menuBreath then
		menuBreath:Destroy()
	end
	if menuMonster then
		menuMonster.Parent = nil -- только у тебя на экране
	end
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	local char = player.Character or player.CharacterAdded:Wait()
	local hum = char:WaitForChild("Humanoid")
	cam.CameraSubject = hum
	if controls then
		controls:Enable()
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
	end)
	if ambience then
		ambience:Play()
	end
	applyVolumes()
	if not fl then
		fl = FL.start()
	end
	hud.Visible = true
	fadeTo(1, 1.3)
	task.delay(1.5, function()
		toast("Встань в светящийся круг у врат, чтобы отправиться. Пульт рядом с вратами — карта, сложность, игроки.", Colors.Text)
		task.wait(1.2)
		toast("Киоски: касса (робуксы), лавка фонарей, аптека (перки), регистратура (титулы). Доска — батлпасс.", Colors.Dim)
	end)
end

menuButton("ИГРАТЬ", 1, function()
	task.spawn(play)
end)
menuButton("КАРТЫ", 2, openMaps)
menuButton("МАГАЗИН", 3, function()
	openShop()
end)
menuButton("БАТЛПАСС", 4, openBP)
menuButton("ПРОФИЛЬ", 5, openProfile)
menuButton("НАСТРОЙКИ", 6, openSettings)

for i, info in ipairs({
	{ "🛒 МАГАЗИН", function()
		openShop()
	end },
	{ "🩸 БАТЛПАСС", openBP },
	{ "🗺 КАРТЫ", openMaps },
	{ "👤 ПРОФИЛЬ", openProfile },
	{ "⚙ НАСТРОЙКИ", openSettings },
}) do
	UI.button({
		Text = info[1],
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = i,
		Parent = sideButtons,
	}, info[2])
end

-- ============================ ДАННЫЕ И СОБЫТИЯ ============================
local function refreshHUD()
	local d = ClientData.get()
	if not d then
		return
	end
	local tier, frac = BattlePass.progress(d.xp or 0)
	coinsLabel.Text = "🪙 " .. tostring(d.coins or 0)
	levelLabel.Text = string.format("УРОВЕНЬ %d  ·  %s", tier, BattlePass.SeasonName)
	xpFill.Size = UDim2.fromScale(tier >= BattlePass.MaxTier and 1 or frac, 1)
	menuStats.Text = string.format("🪙 %d   ·   уровень %d\nпобегов: %d", d.coins or 0, tier, d.stats and d.stats.escapes or 0)
end

local settingsLoaded = false
ClientData.Changed:Connect(function(d)
	if not settingsLoaded then
		settingsLoaded = true
		loadSettings(d)
		refreshSettings()
	end
	refreshHUD()
	if shopWin.frame.Visible then
		renderShop()
	end
	if bpWin.frame.Visible then
		local pos = bpScroll.CanvasPosition
		renderBP(false)
		task.defer(function()
			bpScroll.CanvasPosition = pos
		end)
	end
	if profWin.frame.Visible then
		renderProfile()
	end
end)
refreshHUD()

Remotes.Notify.OnClientEvent:Connect(function(text, color)
	toast(text, color)
end)

Remotes.RoundUpdate.OnClientEvent:Connect(function(kind, which, tab)
	if kind == "open" then
		if which == "shop" then
			openShop(tab)
		elseif which == "battlepass" then
			openBP()
		elseif which == "maps" then
			openMaps()
		elseif which == "gate" then
			openGate(tab)
		end
	elseif kind == "teleportFailed" then
		fadeTo(1, 0.8)
	end
end)

Remotes.Teleporting.OnClientEvent:Connect(function()
	Sound.play("Teleport", nil, { Volume = 0.9 })
	fadeText.Text = "ОНО ЖДЁТ ТЕБЯ..."
	fadeText.TextTransparency = 1
	fadeTo(0, 1.2)
	pcall(function()
		local tg = Instance.new("ScreenGui")
		tg.IgnoreGuiInset = true
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.new(0, 0, 0)
		bg.BorderSizePixel = 0
		bg.Parent = tg
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = "ПАЛАТА 13"
		t.TextColor3 = Color3.fromRGB(200, 30, 30)
		t.Font = Enum.Font.Antique
		t.TextSize = 60
		t.Parent = bg
		TeleportService:SetTeleportGui(tg)
	end)
end)

-- очередь у врат
local lastTime = nil
task.spawn(function()
	while true do
		task.wait(0.2)
		local q = player:GetAttribute("Queue")
		local m = q and GatesFolder:FindFirstChild(q)
		if m and not inMenu then
			gatePanel.Visible = true
			local n = tonumber(string.match(q, "%d+") or "") or 1
			local count = m:GetAttribute("Count") or 0
			local max = m:GetAttribute("Max") or Config.MaxPlayersPerRound
			local left = m:GetAttribute("Time") or 0
			local mapCfg = Config.getMap(m:GetAttribute("Map"))
			local dCfg = Config.getDifficulty(m:GetAttribute("Difficulty"))
			gateTitle.Text = string.format("ВРАТА %s   ·   %d / %d   ·   ОТПРАВКА ЧЕРЕЗ %d", ROMAN[n] or tostring(n), count, max, left)
			gateSub.Text = string.format("%s %s   ·   %s %s", mapCfg.icon, mapCfg.name, dCfg.icon, dCfg.name)
			gateSub.TextColor3 = dCfg.color
			if left ~= lastTime then
				lastTime = left
				if left > 0 and left <= 5 then
					Sound.play("Heartbeat", nil, { Volume = 0.7 })
				else
					Sound.play("UIHover", nil, { Volume = 0.25 })
				end
			end
		else
			gatePanel.Visible = false
			lastTime = nil
		end
	end
end)
local gateBtn = UI.button({
	Text = "⚙ НАСТРОИТЬ",
	TextSize = 15,
	Size = UDim2.fromOffset(130, 36),
	Position = UDim2.new(1, -140, 0.5, -18),
	ZIndex = 3,
	Parent = gatePanel,
}, function()
	local q = player:GetAttribute("Queue")
	if q then
		openGate(q)
	end
end)
local _ = gateBtn

-- лампы лобби слегка реагируют на игрока у врат (жуткий красный)
local lightsFolder = Lobby:FindFirstChild("Lights")
local emergency = lightsFolder and lightsFolder:FindFirstChild("Emergency")
if emergency then
	task.spawn(function()
		while true do
			task.wait(0.1)
			local l = emergency:FindFirstChildWhichIsA("Light")
			if l then
				l.Brightness = player:GetAttribute("Queue") and (1.5 + math.sin(os.clock() * 8)) or 0.6
			end
		end
	end)
end

-- снимаем чёрный экран загрузки — меню готово
task.delay(0.8, function()
	fadeTo(1, 2.2)
end)
local _l = Lighting
