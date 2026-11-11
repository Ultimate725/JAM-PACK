--[[
	ПАЛАТА 13 — клиент ЛОББИ.
	Жуткое главное меню (мигающий фонарик за мышкой, Пациент подходит ближе при каждом затемнении),
	HUD, магазин (робуксы / фонарики / титулы), батлпасс, настройки, очередь у врат.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sound = require(Shared:WaitForChild("Sound"))
local UI = require(Shared:WaitForChild("UI"))
local ClientData = require(Shared:WaitForChild("ClientData"))
local BattlePass = require(Shared:WaitForChild("BattlePass"))
local FL = require(Shared:WaitForChild("FlashlightClient"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Colors = UI.Colors

local Lobby = workspace:WaitForChild("Lobby")
local camPart = Lobby:WaitForChild("MenuCamera")
local menuMonster = Lobby:FindFirstChild("MenuMonster")
local menuPoints = Lobby:FindFirstChild("MenuMonsterPoints")

ClientData.start()

local settings = { music = 0.6, grain = true, flicker = true }
local inMenu = true
local fl = nil

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
local menuMusic = Sound.make("MenuMusic", nil, { Looped = true, Volume = settings.music })
if menuMusic then
	menuMusic:Play()
end
local ambience = Sound.make("Ambience", nil, { Looped = true, Volume = 0 })

local function applyVolumes()
	if menuMusic then
		menuMusic.Volume = inMenu and settings.music or 0
	end
	if ambience then
		ambience.Volume = inMenu and 0 or settings.music * 0.55
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

-- царапины и пыль старой плёнки
local grain = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = menu })
local scratches, dust = {}, {}
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

local _, stopTitle = UI.glitchTitle(menu, "ПАЛАТА 13", UDim2.fromOffset(640, 130), UDim2.new(0.06, 0, 0.13, 0), 112)
local subtitle = UI.label({
	Text = "",
	Font = UI.FontMono,
	TextSize = 20,
	TextColor3 = Colors.Red,
	Size = UDim2.fromOffset(520, 26),
	Position = UDim2.new(0.06, 8, 0.13, 136),
	ZIndex = 6,
	Parent = menu,
})
task.spawn(function()
	local phrases = { "оно не спит", "оно помнит твоё имя", "не свети ему в лицо", "палата 13 свободна. пока." }
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
	Size = UDim2.fromOffset(380, 300),
	Position = UDim2.fromScale(0.06, 0.45),
	BackgroundTransparency = 1,
	ZIndex = 6,
	Parent = menu,
}, {
	UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local menuButtons = {}
local function menuButton(text, order, onClick)
	local b = UI.button({
		Text = "  " .. text,
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 40,
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
	Text = Config.Version .. "   ·   играй в наушниках   ·   не оставайся в темноте",
	Font = UI.FontMono,
	TextSize = 13,
	TextColor3 = Colors.Dim,
	Size = UDim2.fromOffset(600, 18),
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

-- фонарик меню (следит за мышкой и мигает)
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

local blackout = false
local burstUntil = 0
local aim = camPart.Position + camPart.CFrame.LookVector * 50

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
	local sway = CFrame.Angles(
		math.noise(t * 0.25, 1.7) * 0.035 - my * 0.05,
		math.noise(t * 0.25, 5.3) * 0.045 - mx * 0.07,
		math.noise(t * 0.15, 9.1) * 0.012
	)
	cam.CFrame = camPart.CFrame * sway
	cam.FieldOfView = 62

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
	spot.Brightness = 3.7 + math.noise(t * 6, 1) * 0.6
	for _, b in ipairs(menuButtons) do
		if t < burstUntil and settings.flicker then
			b.TextTransparency = on and 0 or 0.65
		elseif b.TextTransparency > 0.5 then
			b.TextTransparency = 0
		end
	end

	-- зерно/царапины
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
	end
end)

-- цикл "блэкаутов": с каждым разом Пациент ближе
local hiddenCF = CFrame.new(0, -500, 0)
local function pointCF(i)
	local p = menuPoints and menuPoints:FindFirstChild("P" .. i)
	return p and p.CFrame
end
if menuMonster and pointCF(1) then
	menuMonster:PivotTo(pointCF(1))
end
task.spawn(function()
	local stage = 1
	while inMenu do
		task.wait(6 + math.random() * 6)
		if not inMenu then
			break
		end
		blackout = true
		Sound.play("FlashlightOff", nil, { Volume = 0.8 })
		sceneDark.BackgroundTransparency = 0.05
		task.wait(0.5 + math.random() * 0.7)
		stage = stage % 4 + 1
		if menuMonster then
			local cf = stage <= 3 and pointCF(stage) or nil
			menuMonster:PivotTo(cf or hiddenCF)
		end
		if not inMenu then
			break
		end
		Sound.play("FlashlightOn", nil, { Volume = 0.8 })
		blackout = false
		sceneDark.BackgroundTransparency = 1
		burstUntil = os.clock() + 0.35
		if stage == 3 then
			-- оно уже рядом
			Sound.play("Whisper", nil, { Volume = 1 })
			Sound.play("Static", nil, { Volume = 0.35 })
			for _ = 1, 6 do
				sceneDark.BackgroundColor3 = Color3.fromRGB(90, 0, 0)
				sceneDark.BackgroundTransparency = 0.7 + math.random() * 0.25
				task.wait(0.05)
			end
			sceneDark.BackgroundColor3 = Color3.new(0, 0, 0)
			sceneDark.BackgroundTransparency = 1
		elseif stage == 4 then
			Sound.play("MetalBang", nil, { Volume = 0.6 })
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

local sideButtons = UI.new("Frame", {
	Size = UDim2.fromOffset(190, 160),
	Position = UDim2.new(1, -20, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	BackgroundTransparency = 1,
	Parent = hud,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local gatePanel = UI.new("Frame", {
	Size = UDim2.fromOffset(560, 74),
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
	Size = UDim2.new(1, 0, 0, 34),
	Position = UDim2.fromOffset(0, 6),
	Parent = gatePanel,
})
local gateSub = UI.label({
	Text = "выйди из круга, чтобы покинуть очередь",
	Font = UI.FontMono,
	TextSize = 13,
	TextColor3 = Colors.Dim,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 18),
	Position = UDim2.fromOffset(0, 44),
	Parent = gatePanel,
})
local _ = gateSub

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

local function toast(text, color)
	UI.toast(gui, text, color)
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

-- ---------- МАГАЗИН ----------
local shopWin = UI.window(gui, "МАГАЗИН", UDim2.new(0.86, 0, 0.84, 0))
table.insert(windows, shopWin)
local shopTabs = UI.new("Frame", {
	Size = UDim2.new(1, -260, 0, 40),
	BackgroundTransparency = 1,
	Parent = shopWin.content,
}, { UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
local shopCoins = UI.label({
	Text = "",
	Font = UI.FontTitle,
	TextSize = 22,
	TextColor3 = Colors.Gold,
	TextXAlignment = Enum.TextXAlignment.Right,
	Size = UDim2.fromOffset(250, 40),
	Position = UDim2.new(1, -250, 0, 0),
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
	Parent = shopWin.content,
}, {
	UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(220, 214),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local currentTab = "robux"
local tabButtons = {}
local renderShop

local function clearChildren(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

local function card(order)
	return UI.new("Frame", {
		BackgroundColor3 = Colors.Panel2,
		BackgroundTransparency = 0.05,
		LayoutOrder = order,
		Parent = shopScroll,
	}, { UI.corner(4), UI.stroke(Colors.Red, 1, 0.55), UI.padding(10) })
end

local function cardText(parent, props)
	props.Parent = parent
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
	return UI.label(props)
end

local function shopAction(action, arg)
	local ok, text = Remotes.ShopRequest:InvokeServer(action, arg)
	toast(text or "", ok and Colors.Green or Colors.Red)
	if ok and action == "buyFlashlight" then
		Sound.play("Purchase", nil, { Volume = 0.8 })
	end
end

renderShop = function()
	local d = ClientData.get() or {}
	local passes = d.passes or {}
	shopCoins.Text = "🪙 " .. tostring(d.coins or 0)
	for k, b in pairs(tabButtons) do
		b.BackgroundColor3 = (k == currentTab) and Color3.fromRGB(120, 18, 18) or Colors.Panel2
	end
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
			UI.button({
				Text = owned and "✓ КУПЛЕНО" or "КУПИТЬ",
				TextSize = 18,
				TextColor3 = owned and Colors.Green or Colors.Text,
				Size = UDim2.new(1, 0, 0, 30),
				Position = UDim2.new(0, 0, 1, -30),
				Parent = c,
			}, function()
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
			UI.button({
				Text = text,
				TextSize = 18,
				TextColor3 = equipped and Colors.Green or Colors.Text,
				Size = UDim2.new(1, 0, 0, 30),
				Position = UDim2.new(0, 0, 1, -30),
				Parent = c,
			}, function()
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
	else
		local titles = d.titles or {}
		for i, t in ipairs(Config.Titles) do
			local c = card(i)
			cardText(c, { Text = "🏷", TextSize = 34, Size = UDim2.new(1, 0, 0, 44) })
			cardText(c, { Text = "«" .. t.name .. "»", Font = UI.FontTitle, TextSize = 20, TextColor3 = t.color, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 50) })
			local has = titles[t.id] == true or (t.id == "VIP" and passes.VIP)
			local src = t.id == "VIP" and "геймпасс VIP" or (t.id == "Newbie" and "есть у всех" or "награда батлпасса")
			cardText(c, { Text = src, Font = UI.FontMono, TextSize = 13, TextColor3 = Colors.Dim, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 108) })
			local selected = d.title == t.id
			UI.button({
				Text = selected and "✓ ВЫБРАН" or (has and "НАДЕТЬ" or "🔒 НЕ ПОЛУЧЕН"),
				TextSize = 18,
				TextColor3 = selected and Colors.Green or Colors.Text,
				Size = UDim2.new(1, 0, 0, 30),
				Position = UDim2.new(0, 0, 1, -30),
				Parent = c,
			}, function()
				if selected then
					return
				end
				if has then
					shopAction("equipTitle", t.id)
				elseif t.id == "VIP" then
					promptPass("VIP")
				else
					toast("Этот титул выдаётся в батлпассе", Colors.Dim)
				end
			end)
		end
	end
end

for i, tab in ipairs({ { "robux", "РОБУКСЫ" }, { "lights", "ФОНАРИКИ" }, { "titles", "ТИТУЛЫ" } }) do
	tabButtons[tab[1]] = UI.button({
		Text = tab[2],
		TextSize = 18,
		Size = UDim2.fromOffset(150, 38),
		LayoutOrder = i,
		Parent = shopTabs,
	}, function()
		currentTab = tab[1]
		renderShop()
	end)
end

-- ---------- БАТЛПАСС ----------
local bpWin = UI.window(gui, "БАТЛПАСС · " .. BattlePass.SeasonName, UDim2.new(0.9, 0, 0.84, 0))
table.insert(windows, bpWin)
local bpLevel = UI.label({
	Text = "",
	Font = UI.FontTitle,
	TextSize = 24,
	Size = UDim2.new(0.5, 0, 0, 28),
	Parent = bpWin.content,
})
local bpBack = UI.new("Frame", {
	Size = UDim2.new(0.42, 0, 0, 10),
	Position = UDim2.fromOffset(0, 34),
	BackgroundColor3 = Color3.fromRGB(25, 12, 12),
	BorderSizePixel = 0,
	Parent = bpWin.content,
}, { UI.stroke(Colors.Red, 1, 0.5) })
local bpFill = UI.new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Colors.Red,
	BorderSizePixel = 0,
	Parent = bpBack,
})
local bpXP = UI.label({
	Text = "",
	Font = UI.FontMono,
	TextSize = 13,
	TextColor3 = Colors.Dim,
	Size = UDim2.new(0.5, 0, 0, 16),
	Position = UDim2.fromOffset(0, 50),
	Parent = bpWin.content,
})
local buyPremium = UI.button({
	Text = "🩸 КУПИТЬ ПРЕМИУМ",
	TextSize = 17,
	TextColor3 = Colors.Gold,
	Size = UDim2.fromOffset(230, 40),
	Position = UDim2.new(1, -470, 0, 6),
	Parent = bpWin.content,
}, function()
	promptPass("PremiumPass")
end)
UI.button({
	Text = "⏭ +1 УРОВЕНЬ",
	TextSize = 17,
	Size = UDim2.fromOffset(230, 40),
	Position = UDim2.new(1, -230, 0, 6),
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
	Parent = bpWin.content,
})
UI.label({
	Text = "ПРЕМИУМ",
	Font = UI.FontBold,
	TextSize = 14,
	TextColor3 = Colors.Gold,
	Size = UDim2.new(0, 86, 0.5, -60),
	Position = UDim2.new(0, 0, 0.5, 46),
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
			Parent = bpScroll,
		})
		UI.label({
			Text = (t == tier) and ("▶ " .. t) or tostring(t),
			Font = UI.FontTitle,
			TextSize = 20,
			TextColor3 = (t <= tier) and Colors.BrightRed or Colors.Dim,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 24),
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

-- ---------- НАСТРОЙКИ ----------
local setWin = UI.window(gui, "НАСТРОЙКИ", UDim2.fromOffset(520, 380))
table.insert(windows, setWin)
local setList = UI.new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = setWin.content,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
local function settingRow(order, labelText)
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = order, Parent = setList })
	UI.label({ Text = labelText, Font = UI.FontBold, TextSize = 18, Size = UDim2.new(0.55, 0, 1, 0), Parent = row })
	return row
end
local musicRow = settingRow(1, "ГРОМКОСТЬ МУЗЫКИ")
local musicValue = UI.label({ Text = "", Font = UI.FontMono, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(70, 44), Position = UDim2.new(1, -150, 0, 0), Parent = musicRow })
local function refreshSettings() end
UI.button({ Text = "−", Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -196, 0, 2), Parent = musicRow }, function()
	settings.music = math.max(0, settings.music - 0.1)
	applyVolumes()
	refreshSettings()
end)
UI.button({ Text = "+", Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -76, 0, 2), Parent = musicRow }, function()
	settings.music = math.min(1, settings.music + 0.1)
	applyVolumes()
	refreshSettings()
end)
local grainRow = settingRow(2, "ЗЕРНО И ЦАРАПИНЫ")
local grainBtn = UI.button({ Text = "", TextSize = 16, Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -196, 0, 2), Parent = grainRow }, function()
	settings.grain = not settings.grain
	refreshSettings()
end)
local flickRow = settingRow(3, "МЕРЦАНИЕ СВЕТА В МЕНЮ")
local flickBtn = UI.button({ Text = "", TextSize = 16, Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -196, 0, 2), Parent = flickRow }, function()
	settings.flicker = not settings.flicker
	refreshSettings()
end)
local statsLabel = UI.label({
	Text = "",
	Font = UI.FontMono,
	TextSize = 15,
	TextColor3 = Colors.Dim,
	Size = UDim2.new(1, 0, 0, 90),
	LayoutOrder = 4,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = setList,
})
refreshSettings = function()
	musicValue.Text = math.floor(settings.music * 100 + 0.5) .. "%"
	grainBtn.Text = settings.grain and "ВКЛ" or "ВЫКЛ"
	flickBtn.Text = settings.flicker and "ВКЛ" or "ВЫКЛ"
	local d = ClientData.get() or {}
	local s = d.stats or {}
	statsLabel.Text = string.format(
		"СТАТИСТИКА\nраундов: %d   побегов: %d   смертей: %d\nжетонов возрождения: %d",
		s.games or 0,
		s.escapes or 0,
		s.deaths or 0,
		d.revives or 0
	)
end
refreshSettings()

local function openShop()
	renderShop()
	openWindow(shopWin)
end
local function openBP()
	renderBP(true)
	openWindow(bpWin)
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
		toast("Встань в светящийся круг у врат, чтобы попасть в больницу.", Colors.Text)
		task.wait(1)
		toast("Торговец в капюшоне — магазин. Доска объявлений — батлпасс. F — фонарик.", Colors.Dim)
	end)
end

menuButton("ИГРАТЬ", 1, function()
	task.spawn(play)
end)
menuButton("МАГАЗИН", 2, openShop)
menuButton("БАТЛПАСС", 3, openBP)
menuButton("НАСТРОЙКИ", 4, openSettings)

for i, info in ipairs({ { "🛒 МАГАЗИН", openShop }, { "🩸 БАТЛПАСС", openBP }, { "⚙ НАСТРОЙКИ", openSettings } }) do
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

ClientData.Changed:Connect(function()
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
	if setWin.frame.Visible then
		refreshSettings()
	end
end)
refreshHUD()

Remotes.Notify.OnClientEvent:Connect(function(text, color)
	toast(text, color)
end)

Remotes.RoundUpdate.OnClientEvent:Connect(function(kind, which)
	if kind == "open" then
		if which == "shop" then
			openShop()
		elseif which == "battlepass" then
			openBP()
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
local GatesFolder = Lobby:WaitForChild("Gates")
local ROMAN = { "I", "II", "III", "IV", "V" }
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
			gateTitle.Text = string.format("ВРАТА %s   ·   %d / %d   ·   ОТПРАВКА ЧЕРЕЗ %d", ROMAN[n] or tostring(n), count, max, left)
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

-- снимаем чёрный экран загрузки — меню готово
task.delay(0.8, function()
	fadeTo(1, 2.2)
end)
