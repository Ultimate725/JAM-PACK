--[[
	ПАЛАТА 13 — сервер ЛОББИ.
	Врата (workspace.Lobby.Gates.Gate1..3): встал в зону -> отсчёт -> телепорт группы в приватный сервер плейса «Больница».
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local Core = ServerScriptService:WaitForChild("Core")
local Remotes = require(Core.Remotes)
local DataService = require(Core.DataService)
local ShopService = require(Core.ShopService)
local BPService = require(Core.BattlePassService)
local FS = require(Core.FlashlightService)

local Config = require(ReplicatedStorage.Shared.Config)
local Sound = require(ReplicatedStorage.Shared.Sound)

DataService.start()
ShopService.start(true)
BPService.start()
FS.start(true) -- в лобби батарея бесконечная

local RED = Color3.fromRGB(220, 50, 50)
local Lobby = workspace:WaitForChild("Lobby")
local GatesFolder = Lobby:WaitForChild("Gates")

local pending = {} -- [player] = true, пока идёт телепорт

local ROMAN = { "I", "II", "III", "IV", "V" }

local function makeSignGui(sign, face)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "GateSign" .. face.Name
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Brightness = 2
	sg.Parent = sign
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.Antique
	t.TextColor3 = Color3.fromRGB(255, 70, 60)
	t.TextStrokeTransparency = 0.3
	t.Text = ""
	t.Parent = sg
	return t
end

local gates = {}
for i, model in ipairs(GatesFolder:GetChildren()) do
	local zone = model:FindFirstChild("Zone", true)
	local sign = model:FindFirstChild("Sign", true)
	if zone then
		local g = {
			name = model.Name,
			model = model,
			zone = zone,
			labels = {},
			queue = {},
			countdown = nil,
			teleporting = false,
			number = tonumber(string.match(model.Name, "%d+") or "") or i,
		}
		if sign then
			table.insert(g.labels, makeSignGui(sign, Enum.NormalId.Front))
			table.insert(g.labels, makeSignGui(sign, Enum.NormalId.Back))
		end
		model:SetAttribute("Max", Config.MaxPlayersPerRound)
		model:SetAttribute("Count", 0)
		model:SetAttribute("Time", 0)
		table.insert(gates, g)
	end
end

local function inZone(zone, pos)
	local rel = zone.CFrame:PointToObjectSpace(pos)
	local h = zone.Size / 2
	return math.abs(rel.X) <= h.X and math.abs(rel.Z) <= h.Z and rel.Y > -h.Y - 3 and rel.Y < h.Y + 8
end

local function setSign(g, text)
	for _, l in ipairs(g.labels) do
		l.Text = text
	end
end

local function teleportGroup(g, list)
	g.teleporting = true
	for _, p in ipairs(list) do
		pending[p] = true
	end
	setSign(g, "ВРАТА " .. (ROMAN[g.number] or g.number) .. "\nОНО ЗОВЁТ...")
	Sound.playAt("Teleport", g.zone.Position, { Volume = 1, RollOffMaxDistance = 80 })

	local function finish(delaySec)
		task.wait(delaySec)
		for _, p in ipairs(list) do
			pending[p] = nil
		end
		g.teleporting = false
		g.countdown = nil
	end

	if RunService:IsStudio() or Config.GamePlaceId == 0 then
		for _, p in ipairs(list) do
			if RunService:IsStudio() then
				Remotes.notify(p, "В Studio телепорт между плейсами не работает. Опубликуй игру и проверь в клиенте Roblox.", RED)
			else
				Remotes.notify(p, "GamePlaceId = 0 в Config. Укажи ID плейса «Больница».", RED)
			end
		end
		finish(3)
		return
	end

	local savedAt = {}
	for _, p in ipairs(list) do
		local ok, t = DataService.saveAsync(p)
		if ok then
			savedAt[tostring(p.UserId)] = t
		end
		p:SetAttribute("AlreadySaved", true)
		Remotes.Teleporting:FireClient(p)
	end
	task.wait(1.5)

	-- игроки могли выйти пока шёл фейд
	local still = {}
	for _, p in ipairs(list) do
		if p.Parent == Players then
			table.insert(still, p)
		end
	end
	if #still == 0 then
		finish(0)
		return
	end

	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	options:SetTeleportData({ savedAt = savedAt, from = "lobby" })
	local ok, err = pcall(function()
		return TeleportService:TeleportAsync(Config.GamePlaceId, still, options)
	end)
	if not ok then
		warn("[Палата13] Телепорт не удался:", err)
		for _, p in ipairs(still) do
			p:SetAttribute("AlreadySaved", nil)
			Remotes.notify(p, "Телепорт не удался: " .. tostring(err), RED)
			Remotes.RoundUpdate:FireClient(p, "teleportFailed")
		end
		finish(2)
		return
	end
	finish(10)
end

TeleportService.TeleportInitFailed:Connect(function(player, result, msg)
	pending[player] = nil
	player:SetAttribute("AlreadySaved", nil)
	Remotes.notify(player, "Ошибка телепорта (" .. tostring(result) .. "): " .. tostring(msg), RED)
	Remotes.RoundUpdate:FireClient(player, "teleportFailed")
end)

Players.PlayerRemoving:Connect(function(p)
	pending[p] = nil
end)

-- основной цикл очередей
local STEP = 0.25
task.spawn(function()
	while true do
		task.wait(STEP)
		local assigned = {}
		for _, g in ipairs(gates) do
			if not g.teleporting then
				-- кто сейчас в зоне
				local inside = {}
				for _, p in ipairs(Players:GetPlayers()) do
					if not pending[p] and not assigned[p] then
						local char = p.Character
						local hrp = char and char:FindFirstChild("HumanoidRootPart")
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if hrp and hum and hum.Health > 0 and inZone(g.zone, hrp.Position) then
							inside[p] = true
						end
					end
				end
				-- сначала те, кто уже стоял в очереди
				local list = {}
				for _, p in ipairs(g.queue) do
					if inside[p] and #list < Config.MaxPlayersPerRound then
						table.insert(list, p)
						inside[p] = nil
					end
				end
				for p in pairs(inside) do
					if #list < Config.MaxPlayersPerRound then
						table.insert(list, p)
					end
				end
				g.queue = list
				for _, p in ipairs(list) do
					assigned[p] = g
				end

				if #list > 0 then
					if not g.countdown then
						g.countdown = Config.QueueCountdown
					else
						g.countdown -= STEP
					end
					if #list >= Config.MaxPlayersPerRound and g.countdown > 5 then
						g.countdown = 5
					end
				else
					g.countdown = nil
				end

				local secs = g.countdown and math.max(0, math.ceil(g.countdown)) or 0
				g.model:SetAttribute("Count", #list)
				g.model:SetAttribute("Time", secs)
				if #list > 0 then
					setSign(g, string.format("ВРАТА %s\n%d / %d\nОТПРАВКА ЧЕРЕЗ %d", ROMAN[g.number] or tostring(g.number), #list, Config.MaxPlayersPerRound, secs))
				else
					setSign(g, string.format("ВРАТА %s\n0 / %d\nВОЙДИ, ЕСЛИ ОСМЕЛИШЬСЯ", ROMAN[g.number] or tostring(g.number), Config.MaxPlayersPerRound))
				end

				if g.countdown and g.countdown <= 0 then
					local group = table.clone(list)
					g.queue = {}
					task.spawn(teleportGroup, g, group)
				end
			else
				for _, p in ipairs(g.queue) do
					assigned[p] = g
				end
			end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			local g = assigned[p]
			local want = g and g.name or nil
			if pending[p] then
				want = nil
			end
			if p:GetAttribute("Queue") ~= want then
				p:SetAttribute("Queue", want)
			end
		end
	end
end)

-- магазин и доска батлпасса — кнопки E в мире
local function prompt(partName, actionText, objectText, which)
	local part = Lobby:FindFirstChild(partName, true)
	if not part then
		warn("[Палата13] Не найден", partName)
		return
	end
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "Prompt"
	pp.ActionText = actionText
	pp.ObjectText = objectText
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 11
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Parent = part
	pp.Triggered:Connect(function(player)
		Remotes.RoundUpdate:FireClient(player, "open", which)
	end)
end
prompt("ShopPrompt", "Магазин", "Торговец без лица", "shop")
prompt("PassPrompt", "Батлпасс", "Доска объявлений", "battlepass")

local _ = ShopService
