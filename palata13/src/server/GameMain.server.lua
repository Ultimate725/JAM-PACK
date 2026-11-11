--[[
	ПАЛАТА 13 — сервер раунда (плейс "Больница").
	Цель: найти 5 предохранителей, вставить в генератор, выбежать через ворота во дворе.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Core = ServerScriptService:WaitForChild("Core")
local Remotes = require(Core.Remotes)
local DataService = require(Core.DataService)
local ShopService = require(Core.ShopService)
local BPService = require(Core.BattlePassService)
local FS = require(Core.FlashlightService)
local MonsterAI = require(Core.MonsterAI)

local Config = require(ReplicatedStorage.Shared.Config)
local Sound = require(ReplicatedStorage.Shared.Sound)

Players.CharacterAutoLoads = false

DataService.start()
ShopService.start(false)
BPService.start()
FS.start(false)

local Map = workspace:WaitForChild("Map")
local Spawns = Map:WaitForChild("Spawns")
local Generator = Map:WaitForChild("Generator")
local Slot = Generator:WaitForChild("Slot")
local ExitZone = Map:WaitForChild("ExitZone")

local R = Config.Round
local round = nil -- текущий раунд
local ai = nil
local pickupFolder = Instance.new("Folder")
pickupFolder.Name = "Pickups"
pickupFolder.Parent = workspace

workspace:SetAttribute("RoundState", "Waiting")
workspace:SetAttribute("Power", false)
workspace:SetAttribute("FusesInserted", 0)
workspace:SetAttribute("FusesNeeded", R.Fuses)
workspace:SetAttribute("TimeLeft", R.TimeLimit)

local function message(text, color)
	Remotes.RoundUpdate:FireAllClients("message", text, color)
end

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

local function ps(player)
	return round and round.players[player]
end

local function isAlive(player)
	local s = ps(player)
	return s ~= nil and s.alive and not s.escaped and not player:GetAttribute("Caught")
end

-- ПРЕДМЕТЫ ---------------------------------------------------------------
local function makeFuse(position)
	local m = Instance.new("Model")
	m.Name = "Fuse"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Cylinder
	body.Size = Vector3.new(1.4, 0.55, 0.55)
	body.Material = Enum.Material.Glass
	body.Color = Color3.fromRGB(255, 190, 60)
	body.Transparency = 0.25
	body.Anchored = true
	body.CanCollide = false
	body.CFrame = CFrame.new(position + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, math.random() * 6.28, 0)
	body.Parent = m
	for _, x in ipairs({ -0.6, 0.6 }) do
		local cap = Instance.new("Part")
		cap.Shape = Enum.PartType.Cylinder
		cap.Size = Vector3.new(0.22, 0.62, 0.62)
		cap.Material = Enum.Material.Metal
		cap.Color = Color3.fromRGB(170, 170, 160)
		cap.Anchored = true
		cap.CanCollide = false
		cap.CFrame = body.CFrame * CFrame.new(x, 0, 0)
		cap.Parent = m
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 170, 50)
	glow.Range = 7
	glow.Brightness = 0.9
	glow.Parent = body
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять"
	prompt.ObjectText = "Предохранитель"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	m.PrimaryPart = body
	m.Parent = pickupFolder
	prompt.Triggered:Connect(function(player)
		if not isAlive(player) or not m.Parent then
			return
		end
		if player:GetAttribute("Fuse") then
			Remotes.notify(player, "Ты уже несёшь предохранитель. Отнеси его в генераторную.")
			return
		end
		Sound.playAt("Pickup", body.Position, { Volume = 0.8 })
		m:Destroy()
		player:SetAttribute("Fuse", true)
		Remotes.notify(player, "Предохранитель у тебя. Генератор — в северо-восточном крыле.", Color3.fromRGB(255, 190, 60))
	end)
	return m
end

local function makeBattery(position)
	local p = Instance.new("Part")
	p.Name = "Battery"
	p.Size = Vector3.new(0.5, 0.9, 0.5)
	p.Shape = Enum.PartType.Block
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(40, 140, 60)
	p.Anchored = true
	p.CanCollide = false
	p.CFrame = CFrame.new(position + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, math.random() * 6.28, 0)
	local tip = Instance.new("Part")
	tip.Size = Vector3.new(0.25, 0.15, 0.25)
	tip.Material = Enum.Material.Metal
	tip.Color = Color3.fromRGB(200, 200, 190)
	tip.Anchored = true
	tip.CanCollide = false
	tip.CFrame = p.CFrame * CFrame.new(0, 0.52, 0)
	tip.Parent = p
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(120, 255, 140)
	glow.Range = 5
	glow.Brightness = 0.6
	glow.Parent = p
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять"
	prompt.ObjectText = "Батарейка"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = p
	p.Parent = pickupFolder
	prompt.Triggered:Connect(function(player)
		if not isAlive(player) or not p.Parent then
			return
		end
		if (player:GetAttribute("Battery") or 0) >= 99 then
			Remotes.notify(player, "Батарея и так полная.")
			return
		end
		Sound.playAt("Pickup", p.Position, { Volume = 0.6, PlaybackSpeed = 1.2 })
		p:Destroy()
		FS.addBattery(player, 40)
		Remotes.notify(player, "+40% батареи", Color3.fromRGB(120, 255, 140))
	end)
	return p
end

local function spawnPickups()
	pickupFolder:ClearAllChildren()
	local fuseSpots = {}
	for _, s in ipairs(Spawns:WaitForChild("Fuse"):GetChildren()) do
		table.insert(fuseSpots, s.Position)
	end
	shuffle(fuseSpots)
	for i = 1, math.min(R.Fuses, #fuseSpots) do
		makeFuse(fuseSpots[i])
	end
	local batSpots = {}
	for _, s in ipairs(Spawns:WaitForChild("Battery"):GetChildren()) do
		table.insert(batSpots, s.Position)
	end
	shuffle(batSpots)
	for i = 1, math.min(R.Batteries, #batSpots) do
		makeBattery(batSpots[i])
	end
end

-- ШКАФЧИКИ -------------------------------------------------------------
local lockers = {}

local function exitLocker(player)
	for locker, occ in pairs(lockers) do
		if occ == player then
			lockers[locker] = nil
			local door = locker:FindFirstChild("Door")
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and door then
				hrp.Anchored = false
				hrp.CFrame = door.CFrame * CFrame.new(0, 0, -3)
			end
			if door then
				Sound.playAt("MetalBang", door.Position, { Volume = 0.25, PlaybackSpeed = 1.7 })
			end
		end
	end
	player:SetAttribute("Hiding", false)
	if ai then
		ai:notifyUnhide(player)
	end
end

local function setupLockers()
	local folder = Map:FindFirstChild("Lockers")
	if not folder then
		return
	end
	for _, locker in ipairs(folder:GetChildren()) do
		local door = locker:FindFirstChild("Door")
		local inside = locker:FindFirstChild("Inside")
		if door and inside then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Спрятаться / Выйти"
			prompt.ObjectText = "Шкафчик"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 7
			prompt.RequiresLineOfSight = false
			prompt.Parent = door
			prompt.Triggered:Connect(function(player)
				if lockers[locker] == player then
					exitLocker(player)
					return
				end
				if not isAlive(player) or player:GetAttribute("Hiding") then
					return
				end
				if lockers[locker] then
					Remotes.notify(player, "Здесь уже кто-то есть...")
					return
				end
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if not hrp then
					return
				end
				lockers[locker] = player
				hrp.Anchored = true
				hrp.CFrame = inside.CFrame
				player:SetAttribute("Hiding", true)
				FS.setOn(player, false)
				Sound.playAt("MetalBang", door.Position, { Volume = 0.25, PlaybackSpeed = 1.6 })
				if ai then
					ai:notifyHide(player)
				end
			end)
		end
	end
end
setupLockers()

-- ГЕНЕРАТОР / ДВЕРИ ---------------------------------------------------------
local doorStates = {}
local function rememberDoor(part)
	if part and part:IsA("BasePart") and not doorStates[part] then
		doorStates[part] = part.CFrame
	end
end
local function doorParts(name)
	local obj = Map:FindFirstChild(name)
	local list = {}
	if obj then
		if obj:IsA("BasePart") then
			table.insert(list, obj)
		end
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
	end
	for _, p in ipairs(list) do
		rememberDoor(p)
	end
	return list
end
local entranceParts = doorParts("EntranceDoor")
local exitParts = doorParts("ExitGate")

local function openDoors(parts, offset, time)
	for _, p in ipairs(parts) do
		TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			CFrame = doorStates[p] + offset,
		}):Play()
	end
end

local function closeDoors()
	for p, cf in pairs(doorStates) do
		p.CFrame = cf
	end
end

local indicators = {}
for i = 1, R.Fuses do
	local ind = Generator:FindFirstChild("I" .. i)
	if ind then
		indicators[i] = ind
	end
end
local function setIndicators(n)
	for i, ind in pairs(indicators) do
		local on = i <= n
		ind.Material = Enum.Material.Neon
		ind.Color = on and Color3.fromRGB(60, 255, 90) or Color3.fromRGB(120, 10, 10)
	end
end
setIndicators(0)

local function powerOn()
	if workspace:GetAttribute("Power") then
		return
	end
	workspace:SetAttribute("Power", true)
	Sound.playAt("GeneratorOn", Slot.Position, { Volume = 1.5, RollOffMaxDistance = 250 })
	message("ГЕНЕРАТОР ЗАПУЩЕН. ВЫХОД ОТКРЫТ. БЕГИ.", Color3.fromRGB(255, 60, 60))
	openDoors(entranceParts, Vector3.new(0, 12, 0), 3)
	openDoors(exitParts, Vector3.new(0, -13, 0), 5)
	if ai then
		ai.enraged = true
		ai:hunt()
	end
end

local slotPrompt = Instance.new("ProximityPrompt")
slotPrompt.ActionText = "Вставить предохранитель"
slotPrompt.ObjectText = "Генератор"
slotPrompt.HoldDuration = 1.2
slotPrompt.MaxActivationDistance = 9
slotPrompt.RequiresLineOfSight = false
slotPrompt.Parent = Slot
slotPrompt.Triggered:Connect(function(player)
	if not round or not isAlive(player) then
		return
	end
	if not player:GetAttribute("Fuse") then
		Remotes.notify(player, "Нужен предохранитель. Ищи их в палатах.")
		return
	end
	player:SetAttribute("Fuse", false)
	round.fuses += 1
	workspace:SetAttribute("FusesInserted", round.fuses)
	setIndicators(round.fuses)
	Sound.playAt("FuseInsert", Slot.Position, { Volume = 1, RollOffMaxDistance = 120 })
	local s = ps(player)
	if s then
		s.fuses += 1
		s.coins += Config.Rewards.Fuse.coins
		s.xp += Config.Rewards.Fuse.xp
	end
	if ai then
		ai.fuses = round.fuses
	end
	if round.fuses >= R.Fuses then
		powerOn()
	else
		message("ПРЕДОХРАНИТЕЛЬ " .. round.fuses .. "/" .. R.Fuses .. ". Оно стало быстрее...", Color3.fromRGB(255, 190, 60))
	end
end)

-- ИГРОКИ -----------------------------------------------------------------
local function dropFuse(player, position)
	if player:GetAttribute("Fuse") then
		player:SetAttribute("Fuse", false)
		if position then
			makeFuse(position - Vector3.new(0, 2.6, 0))
		end
	end
end

local function spawnCharacter(player)
	player:SetAttribute("Caught", false)
	player:SetAttribute("Hiding", false)
	player:SetAttribute("Dead", false)
	player:SetAttribute("Escaped", false)
	player:LoadCharacter()
	local char = player.Character or player.CharacterAdded:Wait()
	local hum = char:WaitForChild("Humanoid")
	hum.WalkSpeed = Config.Player.WalkSpeed
	hum.JumpPower = 38
	hum.UseJumpPower = true
	hum.Died:Connect(function()
		local s = ps(player)
		if s and s.alive and not s.escaped then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			dropFuse(player, hrp and hrp.Position)
			s.alive = false
			player:SetAttribute("Dead", true)
		end
	end)
	return char
end

local function killPlayer(player)
	local s = ps(player)
	if not s or not s.alive then
		return
	end
	exitLocker(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	dropFuse(player, hrp and hrp.Position)
	s.alive = false
	s.coins += Config.Rewards.Death.coins
	s.xp += Config.Rewards.Death.xp
	player:SetAttribute("Dead", true)
	player:SetAttribute("Caught", false)
	FS.setOn(player, false)
	if char then
		-- тело остаётся лежать — страшная находка для других
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hrp then
			hrp.Anchored = false
		end
		if hum then
			hum.BreakJointsOnDeath = true
			hum.Health = 0
		end
	end
	local data = DataService.get(player)
	if data then
		data.stats.deaths += 1
	end
	message(player.DisplayName .. " больше не отвечает...", Color3.fromRGB(200, 40, 40))
end

local function revive(player)
	local s = ps(player)
	if not round or round.ended or not s or s.alive or s.escaped then
		return false
	end
	s.alive = true
	task.spawn(function()
		spawnCharacter(player)
		player:SetAttribute("Battery", 60)
		Remotes.notify(player, "Ты вернулся. Оно знает.", Color3.fromRGB(110, 200, 110))
	end)
	return true
end

ShopService.onRevivePurchased = function(player)
	return revive(player)
end

Remotes.UseRevive.OnServerInvoke = function(player)
	local s = ps(player)
	if not s or s.alive or s.escaped or not round or round.ended then
		return false, "Сейчас нельзя"
	end
	local data = DataService.get(player)
	if not data or data.revives <= 0 then
		return false, "Нет жетонов"
	end
	data.revives -= 1
	DataService.push(player)
	return revive(player), "Возрождение..."
end

Players.PlayerAdded:Connect(function(player)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMaxZoomDistance = 0.5
	if round and not round.ended then
		-- опоздавший: если раунд идёт < 90 сек, запускаем в игру, иначе зритель
		round.players[player] = { alive = false, escaped = false, fuses = 0, coins = 0, xp = 0, joined = os.clock() }
		if os.clock() - round.start < 90 then
			round.players[player].alive = true
			task.spawn(spawnCharacter, player)
		else
			player:SetAttribute("Dead", true)
			Remotes.notify(player, "Раунд уже идёт. Ты наблюдаешь.")
		end
	end
end)
for _, p in ipairs(Players:GetPlayers()) do
	p.CameraMode = Enum.CameraMode.LockFirstPerson
end

Players.PlayerRemoving:Connect(function(player)
	exitLocker(player)
	if round then
		local s = round.players[player]
		if s and player:GetAttribute("Fuse") then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			dropFuse(player, hrp and hrp.Position)
		end
		round.players[player] = nil
	end
end)

-- МОНСТР -----------------------------------------------------------------
local function spawnMonster()
	local template = ServerStorage:FindFirstChild("Monster")
	if not template then
		warn("[Палата13] Нет ServerStorage.Monster")
		return nil
	end
	local old = workspace:FindFirstChild("Monster")
	if old then
		old:Destroy()
	end
	local m = template:Clone()
	m.Name = "Monster"
	local spawnPart = Map:FindFirstChild("MonsterSpawn")
	if spawnPart then
		m:PivotTo(spawnPart.CFrame)
	end
	m.Parent = workspace
	return MonsterAI.new(m, Map, {
		isAlive = isAlive,
		onCatch = function(player)
			killPlayer(player)
		end,
		onDragOut = function(player)
			exitLocker(player)
		end,
	})
end

-- РАУНД ------------------------------------------------------------------
local function countAlive()
	local n = 0
	for p, s in pairs(round.players) do
		if p.Parent and s.alive and not s.escaped then
			n += 1
		end
	end
	return n
end

local function finishRound()
	round.ended = true
	workspace:SetAttribute("RoundState", "Ended")
	if ai then
		ai:stop()
	end
	local savedAt = {}
	for player, s in pairs(round.players) do
		if player.Parent then
			local data = DataService.get(player)
			local survived = os.clock() - round.start
			local surviveXP = math.floor(survived / 10) * Config.Rewards.SurviveXPPer10s
			s.xp += surviveXP
			if s.escaped then
				s.coins += Config.Rewards.Escape.coins
				s.xp += Config.Rewards.Escape.xp
			end
			local vip = ShopService.hasPass(player, "VIP")
			local coins = vip and s.coins * 2 or s.coins
			if data then
				data.coins += coins
				data.stats.games += 1
				if s.escaped then
					data.stats.escapes += 1
				end
			end
			BPService.addXP(player, s.xp)
			DataService.push(player)
			Remotes.Results:FireClient(player, {
				escaped = s.escaped,
				fuses = s.fuses,
				coins = coins,
				vip = vip,
				xp = s.xp,
				time = math.floor(survived),
				totalFuses = round.fuses,
			})
		end
	end
	task.wait(R.ReturnToLobbyDelay)

	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local ok, t = DataService.saveAsync(player)
		if ok then
			savedAt[tostring(player.UserId)] = t
		end
		table.insert(list, player)
	end

	if Config.LobbyPlaceId == 0 or RunService:IsStudio() then
		message(RunService:IsStudio() and "В Studio телепорт в лобби не работает. Новый раунд..." or "LobbyPlaceId не задан в Config. Новый раунд...")
		return false
	end
	for _, p in ipairs(list) do
		p:SetAttribute("AlreadySaved", true)
	end
	Remotes.Teleporting:FireAllClients()
	task.wait(1.2)
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ savedAt = savedAt, from = "game" })
	local ok, err = pcall(function()
		return TeleportService:TeleportAsync(Config.LobbyPlaceId, list, options)
	end)
	if not ok then
		warn("[Палата13] Телепорт в лобби не удался:", err)
		for _, p in ipairs(list) do
			p:SetAttribute("AlreadySaved", nil)
		end
		message("Телепорт не удался. Новый раунд...")
		return false
	end
	return true
end

TeleportService.TeleportInitFailed:Connect(function(player, _, msg)
	player:SetAttribute("AlreadySaved", nil)
	Remotes.notify(player, "Ошибка телепорта: " .. tostring(msg) .. ". Перезайди в игру.")
end)

local function resetMap()
	workspace:SetAttribute("Power", false)
	workspace:SetAttribute("FusesInserted", 0)
	closeDoors()
	setIndicators(0)
	for _, p in ipairs(Players:GetPlayers()) do
		exitLocker(p)
	end
	lockers = {}
	spawnPickups()
end

local function runRound()
	-- ждём игроков (остальные из группы ещё грузятся)
	workspace:SetAttribute("RoundState", "Waiting")
	while #Players:GetPlayers() == 0 do
		task.wait(0.5)
	end
	for i = R.WaitForPlayers, 1, -1 do
		workspace:SetAttribute("TimeLeft", i)
		Remotes.RoundUpdate:FireAllClients("waiting", i)
		task.wait(1)
	end

	resetMap()
	round = { players = {}, fuses = 0, start = os.clock(), ended = false }
	for _, player in ipairs(Players:GetPlayers()) do
		round.players[player] = { alive = true, escaped = false, fuses = 0, coins = 0, xp = 0, joined = os.clock() }
		player:SetAttribute("Battery", 100)
		player:SetAttribute("Fuse", false)
		player:SetAttribute("FlashlightOn", false)
		player:SetAttribute("AlreadySaved", nil)
		task.spawn(spawnCharacter, player)
	end
	workspace:SetAttribute("RoundState", "Playing")
	message("НАЙДИ 5 ПРЕДОХРАНИТЕЛЕЙ. ЗАПУСТИ ГЕНЕРАТОР. НЕ ШУМИ.", Color3.fromRGB(235, 225, 215))

	ai = spawnMonster()
	local woke = false
	local lastXpTick = os.clock()
	while true do
		task.wait(0.25)
		local elapsed = os.clock() - round.start
		local left = math.max(0, R.TimeLimit - elapsed)
		workspace:SetAttribute("TimeLeft", math.floor(left))

		if not woke and elapsed >= R.MonsterWakeDelay and ai then
			woke = true
			ai:wake()
			message("В МОРГЕ ЧТО-ТО ПРОСНУЛОСЬ.", Color3.fromRGB(255, 40, 40))
		end

		-- побег
		if workspace:GetAttribute("Power") then
			for player, s in pairs(round.players) do
				if s.alive and not s.escaped then
					local char = player.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					if hrp then
						local rel = ExitZone.CFrame:PointToObjectSpace(hrp.Position)
						local half = ExitZone.Size / 2
						if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y + 4 and math.abs(rel.Z) <= half.Z then
							s.escaped = true
							player:SetAttribute("Escaped", true)
							FS.setOn(player, false)
							message(player.DisplayName .. " сбежал из Палаты 13!", Color3.fromRGB(110, 220, 110))
							if char then
								char:Destroy()
							end
						end
					end
				end
			end
		end

		-- время вышло: оно забирает всех
		if left <= 0 then
			for player, s in pairs(round.players) do
				if s.alive and not s.escaped and player.Parent then
					Remotes.Jumpscare:FireClient(player, workspace:FindFirstChild("Monster"))
				end
			end
			task.wait(2.4)
			for player, s in pairs(round.players) do
				if s.alive and not s.escaped then
					killPlayer(player)
				end
			end
		end

		if os.clock() - lastXpTick > 1 then
			lastXpTick = os.clock()
		end

		if countAlive() == 0 then
			break
		end
	end
	local anyEscaped = false
	for _, s in pairs(round.players) do
		if s.escaped then
			anyEscaped = true
		end
	end
	message(anyEscaped and "РАУНД ОКОНЧЕН. КТО-ТО ВЫБРАЛСЯ." or "НИКТО НЕ ВЫШЕЛ ИЗ ПАЛАТЫ 13.", Color3.fromRGB(255, 60, 60))
	task.wait(2.5)
	return finishRound()
end

task.spawn(function()
	while true do
		local teleported = runRound()
		if teleported then
			-- сервер опустеет и закроется; если кто-то остался — новый раунд
			task.wait(10)
		end
		local m = workspace:FindFirstChild("Monster")
		if m then
			m:Destroy()
		end
		ai = nil
		round = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then
				p.Character:Destroy()
			end
			p:SetAttribute("Dead", false)
			p:SetAttribute("Escaped", false)
		end
	end
end)
