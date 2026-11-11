--[[
	ПАЛАТА 13 — сервер раунда (игровой плейс).
	Карта выбирается у врат в лобби и приходит в TeleportData: { map, difficulty, maxPlayers }.
	Все карты лежат в ServerStorage.Maps.<id> и клонируются в workspace.Map на старте раунда.
	Цель: найти предохранители, вставить в генераторы, починить их (удерживать E),
	включить свет -> открыть ворота -> выбежать в зону выхода.
	В Studio карту/сложность можно задать атрибутами workspace: TestMap, TestDifficulty.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

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

local Maps = ServerStorage:WaitForChild("Maps")
local Monsters = ServerStorage:WaitForChild("Monsters")

local R = Config.Round
local round = nil -- текущий раунд
local ai = nil
local Map = nil
local pickupFolder = Instance.new("Folder")
pickupFolder.Name = "Pickups"
pickupFolder.Parent = workspace

-- НАСТРОЙКИ СЕССИИ (из телепорта) -------------------------------------------
local session = { map = nil, difficulty = nil, maxPlayers = Config.MaxPlayersPerRound }

local function readTeleportData(player)
	local ok, td = pcall(function()
		local join = player:GetJoinData()
		return join and join.TeleportData
	end)
	if not ok or type(td) ~= "table" then
		return
	end
	if type(td.map) == "string" and Maps:FindFirstChild(td.map) and not session.map then
		session.map = td.map
	end
	if type(td.difficulty) == "string" and not session.difficulty then
		for _, d in ipairs(Config.Difficulties) do
			if d.id == td.difficulty then
				session.difficulty = d.id
			end
		end
	end
	if type(td.maxPlayers) == "number" then
		session.maxPlayers = math.clamp(math.floor(td.maxPlayers), 1, Config.MaxPlayersPerRound)
	end
end

local function resolveSession()
	local mapId = session.map or workspace:GetAttribute("TestMap")
	if type(mapId) ~= "string" or not Maps:FindFirstChild(mapId) then
		mapId = Maps:FindFirstChild("Hospital") and "Hospital" or (Maps:GetChildren()[1] and Maps:GetChildren()[1].Name)
	end
	local diffId = session.difficulty or workspace:GetAttribute("TestDifficulty")
	local diff = Config.getDifficulty(diffId)
	return mapId, diff
end

workspace:SetAttribute("RoundState", "Waiting")
workspace:SetAttribute("Power", false)
workspace:SetAttribute("GensDone", 0)
workspace:SetAttribute("GensNeeded", 3)
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

local function partsOf(obj)
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
	return list
end

-- КАРТА ---------------------------------------------------------------------
local function applyLighting(mapCfg)
	local l = mapCfg.lighting or {}
	Lighting.FogEnd = l.fog or 400
	Lighting.FogStart = 0
	if l.ambient then
		Lighting.Ambient = l.ambient
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm and l.density then
		atm.Density = l.density
	end
	local grade = Lighting:FindFirstChild("Grade")
	if grade and l.tint then
		grade.TintColor = l.tint
	end
end

local function loadMap(mapId)
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local template = Maps:FindFirstChild(mapId)
	local m = template:Clone()
	m.Name = "Map"
	m.Parent = workspace
	Map = m
	workspace:SetAttribute("Map", mapId)
	applyLighting(Config.getMap(mapId))
	return m
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
		local have = player:GetAttribute("Fuses") or 0
		if have >= (R.MaxFuses or 2) then
			Remotes.notify(player, "Карманы полны: больше " .. (R.MaxFuses or 2) .. " предохранителей не унести.")
			return
		end
		Sound.playAt("Pickup", body.Position, { Volume = 0.8 })
		m:Destroy()
		player:SetAttribute("Fuses", have + 1)
		Remotes.notify(player, "Предохранитель в инвентаре (" .. (have + 1) .. "). Вставь его в любой генератор.", Color3.fromRGB(255, 190, 60))
	end)
	return m
end

-- ЗАПИСКИ: сюжет карты. Записка остаётся на месте — каждый игрок забирает свою копию.
local function noteList(player)
	local list = {}
	for id in string.gmatch(player:GetAttribute("Notes") or "", "%d+") do
		list[tonumber(id)] = true
	end
	return list
end

local function makeNote(position, noteId)
	local p = Instance.new("Part")
	p.Name = "Note"
	p.Size = Vector3.new(1.3, 0.05, 1.7)
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(214, 204, 178)
	p.Anchored = true
	p.CanCollide = false
	p.CFrame = CFrame.new(position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, math.random() * 6.28, 0)
	local ink = Instance.new("Part")
	ink.Size = Vector3.new(0.9, 0.06, 0.08)
	ink.Material = Enum.Material.SmoothPlastic
	ink.Color = Color3.fromRGB(90, 8, 10)
	ink.Anchored = true
	ink.CanCollide = false
	ink.CFrame = p.CFrame * CFrame.new(0, 0.01, -0.3)
	ink.Parent = p
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 230, 190)
	glow.Range = 4
	glow.Brightness = 0.35
	glow.Parent = p
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять записку"
	prompt.ObjectText = "Записка " .. noteId
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = p
	p.Parent = pickupFolder
	prompt.Triggered:Connect(function(player)
		if not isAlive(player) or not p.Parent then
			return
		end
		local list = noteList(player)
		if not list[noteId] then
			list[noteId] = true
			local ids = {}
			for id in pairs(list) do
				table.insert(ids, id)
			end
			table.sort(ids)
			player:SetAttribute("Notes", table.concat(ids, ","))
			local s = ps(player)
			if s then
				s.coins += Config.Rewards.Note.coins
				s.xp += Config.Rewards.Note.xp
			end
			Sound.playAt("Paper", p.Position, { Volume = 0.8, RollOffMaxDistance = 25 })
		end
		Remotes.RoundUpdate:FireClient(player, "note", noteId)
	end)
	return p
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

local function spawnPickups(fuseCount)
	pickupFolder:ClearAllChildren()
	local spawns = Map:FindFirstChild("Spawns")
	local fuseSpots, batSpots = {}, {}
	if spawns then
		for _, s in ipairs(spawns:FindFirstChild("Fuse") and spawns.Fuse:GetChildren() or {}) do
			table.insert(fuseSpots, s.Position)
		end
		for _, s in ipairs(spawns:FindFirstChild("Battery") and spawns.Battery:GetChildren() or {}) do
			table.insert(batSpots, s.Position)
		end
	end
	shuffle(fuseSpots)
	for i = 1, math.min(fuseCount, #fuseSpots) do
		makeFuse(fuseSpots[i])
	end
	-- записки лежат на оставшихся точках предохранителей
	local notes = Config.Notes[workspace:GetAttribute("Map")] or {}
	for n = 1, #notes do
		local spot = fuseSpots[fuseCount + n]
		if spot then
			makeNote(spot, n)
		end
	end
	shuffle(batSpots)
	for i = 1, math.min(R.Batteries, #batSpots) do
		makeBattery(batSpots[i])
	end
end

-- ШКАФЧИКИ -------------------------------------------------------------
local lockers = {}
local lockerConns = {}

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
				FS.emitNoise(player, door.Position, "interact")
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
			prompt.ObjectText = "Укрытие"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 7
			prompt.RequiresLineOfSight = false
			prompt.Parent = door
			table.insert(lockerConns, prompt.Triggered:Connect(function(player)
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
				FS.setCrouch(player, false)
				lockers[locker] = player
				hrp.Anchored = true
				hrp.CFrame = inside.CFrame
				player:SetAttribute("Hiding", true)
				FS.setOn(player, false)
				Sound.playAt("MetalBang", door.Position, { Volume = 0.25, PlaybackSpeed = 1.6 })
				FS.emitNoise(player, door.Position, "interact")
				if ai then
					ai:notifyHide(player)
				end
			end))
		end
	end
end

-- ГЕНЕРАТОРЫ / ВОРОТА ---------------------------------------------------------
local gens = {}
local doorStates = {}
local gateConns = {}

local function rememberDoors(obj)
	for _, p in ipairs(partsOf(obj)) do
		if not doorStates[p] then
			doorStates[p] = p.CFrame
		end
	end
end

local function openDoors(obj, defaultOffset, defaultTime)
	if not obj then
		return
	end
	local offset = obj:GetAttribute("OpenOffset")
	if typeof(offset) ~= "Vector3" then
		offset = defaultOffset
	end
	local time = obj:GetAttribute("OpenTime") or defaultTime
	local sndPart = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
	if sndPart then
		Sound.playAt("GateOpen", sndPart.Position, { Volume = 1.2, RollOffMaxDistance = 220 })
	end
	for _, p in ipairs(partsOf(obj)) do
		TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			CFrame = doorStates[p] + offset,
		}):Play()
	end
end

local function exitGates()
	local list = {}
	local folder = Map:FindFirstChild("ExitGates")
	if folder then
		for _, g in ipairs(folder:GetChildren()) do
			table.insert(list, g)
		end
	end
	local single = Map:FindFirstChild("ExitGate")
	if single then
		table.insert(list, single)
	end
	return list
end

local function exitZones()
	local list = {}
	local folder = Map:FindFirstChild("ExitZones")
	if folder then
		for _, z in ipairs(folder:GetChildren()) do
			if z:IsA("BasePart") then
				table.insert(list, z)
			end
		end
	end
	local single = Map:FindFirstChild("ExitZone")
	if single then
		table.insert(list, single)
	end
	return list
end

local function setIndicators(g)
	for i, ind in ipairs(g.indicators) do
		local on
		if g.done then
			on = true
		elseif g.fused then
			on = (i - 1) / math.max(1, #g.indicators) < g.progress
		else
			on = false
		end
		ind.Material = Enum.Material.Neon
		ind.Color = on and Color3.fromRGB(60, 255, 90) or (g.fused and Color3.fromRGB(255, 170, 40) or Color3.fromRGB(120, 10, 10))
	end
	g.model:SetAttribute("Progress", g.progress)
	g.model:SetAttribute("Fused", g.fused)
	g.model:SetAttribute("Done", g.done)
end

local function powerOn()
	if workspace:GetAttribute("Power") then
		return
	end
	workspace:SetAttribute("Power", true)
	message("ТОК ПОДАН. ВОРОТА ОТКРЫВАЮТСЯ. БЕГИ К ВЫХОДУ.", Color3.fromRGB(255, 60, 60))
	for _, g in ipairs(gens) do
		local engine = g.model:FindFirstChild("Engine") or g.slot
		Sound.playAt("GeneratorOn", engine.Position, { Volume = 1.5, RollOffMaxDistance = 250 })
	end
	openDoors(Map:FindFirstChild("EntranceDoor"), Vector3.new(0, 12, 0), 3)
	for _, gate in ipairs(exitGates()) do
		openDoors(gate, Vector3.new(0, -13, 0), 5)
	end
	if ai then
		ai.enraged = true
		ai.model:SetAttribute("Enraged", true)
		ai:hunt()
	end
end

-- скорость починки одним игроком (1 = базовая)
local function repairMult(player)
	local perk = player:GetAttribute("Perk_repair")
	return type(perk) == "number" and perk or 1
end

-- секунд починки одним игроком без перков на текущей сложности
local function repairTime()
	return (round and round.difficulty.repair) or R.RepairTime
end

local REPAIR_REACH = 11 -- дальше от слота — починка прерывается

-- места у панели: по центру, затем слева/справа (для помощников)
local KNEEL_SIDE = { 0, -2.2, 2.2, -4.4 }

local function freeze(player, slot, place)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.AutoRotate = false
	end
	if hrp and slot then
		-- ставим на колено вплотную к панели (лицевая сторона слота смотрит по его LookVector)
		local out = slot.CFrame.LookVector
		local side = slot.CFrame.RightVector * (KNEEL_SIDE[place] or 0)
		local spot = slot.Position + out * 2.7 + side
		spot = Vector3.new(spot.X, hrp.Position.Y, spot.Z)
		local face = Vector3.new(slot.Position.X + side.X, spot.Y, slot.Position.Z + side.Z)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = CFrame.lookAt(spot, face)
	end
end

local function unfreeze(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.WalkSpeed = Config.Player.WalkSpeed
		hum.JumpPower = 38
		hum.AutoRotate = true
	end
end

local function updateRepairFx(g)
	local busy = next(g.repairers) ~= nil
	local sparks = g.slot:FindFirstChild("Sparks")
	if sparks then
		sparks.Enabled = busy
		sparks.Rate = busy and 14 or 0
	end
	if g.crank then
		if busy and not g.crank.IsPlaying then
			g.crank:Play()
		elseif not busy and g.crank.IsPlaying then
			g.crank:Stop()
		end
	end
	local count = 0
	for _ in pairs(g.repairers) do
		count += 1
	end
	g.model:SetAttribute("Repairers", count)
end

local function stopRepair(g, player)
	if not g.repairers[player] then
		return
	end
	g.repairers[player] = nil
	player:SetAttribute("Repairing", nil)
	player:SetAttribute("RepairProgress", nil)
	unfreeze(player)
	updateRepairFx(g)
end

local function stopAllRepairs(player)
	for _, g in ipairs(gens) do
		if g.repairers and g.repairers[player] then
			stopRepair(g, player)
		end
	end
	player:SetAttribute("Repairing", nil)
	player:SetAttribute("RepairProgress", nil)
end

local function generatorDone(g, player)
	g.done = true
	g.progress = 1
	for p in pairs(g.repairers) do
		stopRepair(g, p)
	end
	g.prompt.Enabled = false
	setIndicators(g)
	round.gensDone += 1
	workspace:SetAttribute("GensDone", round.gensDone)
	local engine = g.model:FindFirstChild("Engine") or g.slot
	Sound.playAt("GeneratorOn", engine.Position, { Volume = 1.1, RollOffMaxDistance = 180 })
	FS.emitNoise(player, engine.Position, "interact")
	-- включаем лампы самого генератора
	for _, d in ipairs(g.model:GetDescendants()) do
		if d:IsA("Light") then
			d.Enabled = true
		elseif d:IsA("ParticleEmitter") and d.Name == "Exhaust" then
			d.Enabled = true
		end
	end
	local s = ps(player)
	if s then
		s.generators += 1
		s.coins += Config.Rewards.Generator.coins
		s.xp += Config.Rewards.Generator.xp
	end
	if ai then
		ai.generators = round.gensDone
	end
	if round.gensDone >= round.gensNeeded then
		powerOn()
	else
		message(string.format("ГЕНЕРАТОР %d/%d ЗАПУЩЕН. Оно слышало это...", round.gensDone, round.gensNeeded), Color3.fromRGB(255, 190, 60))
	end
end

local function setupGenerators()
	gens = {}
	local list = {}
	local folder = Map:FindFirstChild("Generators")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			table.insert(list, m)
		end
	end
	local single = Map:FindFirstChild("Generator")
	if single then
		table.insert(list, single)
	end
	for _, model in ipairs(list) do
		local slot = model:FindFirstChild("Slot", true)
		if slot then
			local g = { model = model, slot = slot, indicators = {}, fused = false, done = false, progress = 0, repairers = {} }
			for i = 1, 8 do
				local ind = model:FindFirstChild("I" .. i, true)
				if ind then
					table.insert(g.indicators, ind)
				end
			end
			g.crank = Sound.make("GeneratorCrank", slot, { Looped = true, Volume = 0.8, RollOffMinDistance = 10, RollOffMaxDistance = 90 })
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Вставить предохранитель"
			prompt.ObjectText = "Генератор"
			prompt.HoldDuration = 0.6
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Parent = slot
			g.prompt = prompt
			setIndicators(g)

			prompt.Triggered:Connect(function(player)
				if not round or g.done then
					return
				end
				-- повторное E — встать и отойти
				if g.repairers[player] then
					stopRepair(g, player)
					return
				end
				if not isAlive(player) or player:GetAttribute("Hiding") then
					return
				end
				if not g.fused then
					if (player:GetAttribute("Fuses") or 0) <= 0 then
						Remotes.notify(player, "Нужен предохранитель. Ищи их по карте.")
						return
					end
					player:SetAttribute("Fuses", player:GetAttribute("Fuses") - 1)
					g.fused = true
					setIndicators(g)
					Sound.playAt("FuseInsert", slot.Position, { Volume = 1, RollOffMaxDistance = 120 })
					FS.emitNoise(player, slot.Position, "interact")
					local s = ps(player)
					if s then
						s.fuses += 1
						s.coins += Config.Rewards.Fuse.coins
						s.xp += Config.Rewards.Fuse.xp
					end
					prompt.ActionText = "Чинить / встать (E)"
					prompt.HoldDuration = 0.25
					Remotes.notify(player, string.format("Предохранитель вставлен. Чини: E — начать, E — встать. Один человек — ~%d сек, вдвоём быстрее. Это шумно.", math.floor(repairTime() / repairMult(player))), Color3.fromRGB(255, 190, 60))
					return
				end
				-- начать починку: персонаж садится к панели и не может двигаться
				stopAllRepairs(player)
				FS.setCrouch(player, false)
				FS.setOn(player, false)
				local used = {}
				for _, pl in pairs(g.repairers) do
					used[pl] = true
				end
				local place = 1
				while used[place] do
					place += 1
				end
				if place > #KNEEL_SIDE then
					Remotes.notify(player, "У генератора нет места.")
					return
				end
				g.repairers[player] = place
				player:SetAttribute("Repairing", model.Name)
				player:SetAttribute("RepairProgress", g.progress)
				freeze(player, slot, place)
				FS.emitNoise(player, slot.Position, "interact")
				updateRepairFx(g)
			end)
			table.insert(gens, g)
		end
	end
	-- прогресс тикает, пока у генератора кто-то сидит (частичный прогресс сохраняется)
	task.spawn(function()
		local myRound = round
		local STEP = 0.25
		while round == myRound and round and not round.ended do
			task.wait(STEP)
			for _, g in ipairs(gens) do
				if not g.done and next(g.repairers) then
					local rate = 0
					local last = nil
					for p in pairs(g.repairers) do
						local char = p.Character
						local hrp = char and char:FindFirstChild("HumanoidRootPart")
						if not p.Parent or not isAlive(p) or not hrp or (hrp.Position - g.slot.Position).Magnitude > REPAIR_REACH then
							stopRepair(g, p)
						else
							-- каждый следующий помощник даёт чуть меньше
							rate += repairMult(p) * (rate > 0 and 0.75 or 1)
							last = p
						end
					end
					if last then
						g.progress = math.min(1, g.progress + STEP * rate / repairTime())
						setIndicators(g)
						for p in pairs(g.repairers) do
							p:SetAttribute("RepairProgress", g.progress)
						end
						if math.random() < 0.3 then
							FS.emitNoise(last, g.slot.Position, "interact")
						end
						if g.progress >= 1 then
							generatorDone(g, last)
						end
					end
				end
			end
		end
	end)
	return #gens
end

-- ИГРОКИ -----------------------------------------------------------------
local function dropFuse(player, position)
	local n = player:GetAttribute("Fuses") or 0
	if n > 0 then
		player:SetAttribute("Fuses", 0)
		if position then
			for i = 1, n do
				makeFuse(position - Vector3.new(0, 2.6, 0) + Vector3.new((i - 1) * 1.2, 0, 0))
			end
		end
	end
end

local function spawnCharacter(player)
	player:SetAttribute("Caught", false)
	player:SetAttribute("Hiding", false)
	player:SetAttribute("Dead", false)
	player:SetAttribute("Escaped", false)
	player:SetAttribute("Repairing", nil)
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
	local spawnPart = Map and Map:FindFirstChild("SpawnLocation")
	if spawnPart then
		char:PivotTo(spawnPart.CFrame * CFrame.new(math.random(-3, 3), 3, math.random(-3, 3)))
	end
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
	stopAllRepairs(player)
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

-- запасные батарейки (перк): автоматически, когда батарея села
local function watchBattery(player)
	player:GetAttributeChangedSignal("Battery"):Connect(function()
		local b = player:GetAttribute("Battery") or 0
		local spare = player:GetAttribute("SpareBatteries") or 0
		if b <= 0 and spare > 0 and isAlive(player) then
			player:SetAttribute("SpareBatteries", spare - 1)
			FS.addBattery(player, 40)
			Remotes.notify(player, "Запасная батарейка вставлена (осталось " .. (spare - 1) .. ")", Color3.fromRGB(120, 255, 140))
		end
	end)
end

local function onPlayer(player)
	readTeleportData(player)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMaxZoomDistance = 0.5
	watchBattery(player)
	player:SetAttribute("Fuses", 0)
	player:SetAttribute("Notes", "")
	if round and not round.ended then
		-- опоздавший: если раунд идёт < 90 сек, запускаем в игру, иначе зритель
		round.players[player] = { alive = false, escaped = false, fuses = 0, generators = 0, coins = 0, xp = 0, joined = os.clock() }
		if os.clock() - round.start < 90 then
			round.players[player].alive = true
			task.spawn(spawnCharacter, player)
		else
			player:SetAttribute("Dead", true)
			Remotes.notify(player, "Раунд уже идёт. Ты наблюдаешь.")
		end
		Remotes.RoundUpdate:FireClient(player, "intro", round.mapId, round.difficulty.id)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end

Players.PlayerRemoving:Connect(function(player)
	exitLocker(player)
	stopAllRepairs(player)
	if round then
		local s = round.players[player]
		if s and (player:GetAttribute("Fuses") or 0) > 0 then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			dropFuse(player, hrp and hrp.Position)
		end
		round.players[player] = nil
	end
end)

-- МОНСТР -----------------------------------------------------------------
local function spawnMonster(diff)
	local template = diff.blind and Monsters:FindFirstChild("Blind") or Monsters:FindFirstChild("Patient")
	template = template or Monsters:FindFirstChildOfClass("Model")
	if not template then
		warn("[Палата13] Нет ServerStorage.Monsters")
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
		m:PivotTo(spawnPart.CFrame + Vector3.new(0, 5, 0))
	end
	m.Parent = workspace
	return MonsterAI.new(m, Map, {
		difficulty = diff,
		isAlive = isAlive,
		noiseSignal = FS.Noise,
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

local function grantTitles(player, data, s)
	local diff, mapId = round.difficulty, round.mapId
	if s.escaped then
		data.stats.mapsEscaped = data.stats.mapsEscaped or {}
		data.stats.mapsEscaped[mapId] = (data.stats.mapsEscaped[mapId] or 0) + 1
		for _, t in ipairs(Config.Titles) do
			if t.source == "map:" .. mapId and not data.titles[t.id] then
				data.titles[t.id] = true
				Remotes.notify(player, "Новый титул: «" .. t.name .. "»", Color3.fromRGB(235, 185, 70))
			end
		end
		if diff.id == "Nightmare" then
			data.stats.nightmareEscapes = (data.stats.nightmareEscapes or 0) + 1
			if not data.titles.Unkillable then
				data.titles.Unkillable = true
				Remotes.notify(player, "Новый титул: «Неубиваемый»", Color3.fromRGB(255, 255, 255))
			end
		end
	end
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
			s.xp = math.floor(s.xp * round.difficulty.xpMult)
			s.coins = math.floor(s.coins * round.difficulty.coinMult)
			local vip = ShopService.hasPass(player, "VIP")
			local coins = vip and s.coins * 2 or s.coins
			if data then
				data.coins += coins
				data.stats.games += 1
				data.stats.generators = (data.stats.generators or 0) + s.generators
				if s.escaped then
					data.stats.escapes += 1
				end
				grantTitles(player, data, s)
			end
			BPService.addXP(player, s.xp)
			DataService.push(player)
			Remotes.Results:FireClient(player, {
				escaped = s.escaped,
				fuses = s.fuses,
				generators = s.generators,
				coins = coins,
				vip = vip,
				xp = s.xp,
				time = math.floor(survived),
				totalGens = round.gensDone,
				map = round.mapId,
				difficulty = round.difficulty.id,
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

local function resetMap(mapId, diff)
	for _, c in ipairs(lockerConns) do
		c:Disconnect()
	end
	lockerConns = {}
	for _, c in ipairs(gateConns) do
		c:Disconnect()
	end
	gateConns = {}
	doorStates = {}
	lockers = {}
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("Hiding", false)
	end
	loadMap(mapId)
	workspace:SetAttribute("Power", false)
	workspace:SetAttribute("GensDone", 0)
	setupLockers()
	rememberDoors(Map:FindFirstChild("EntranceDoor"))
	for _, gate in ipairs(exitGates()) do
		rememberDoors(gate)
	end
	local total = setupGenerators()
	local needed = math.clamp(diff.generators, 1, math.max(1, total))
	workspace:SetAttribute("GensNeeded", needed)
	spawnPickups(needed + 1)
	return needed
end

local function runRound()
	-- ждём игроков (остальные из группы ещё грузятся)
	workspace:SetAttribute("RoundState", "Waiting")
	while #Players:GetPlayers() == 0 do
		task.wait(0.5)
	end
	local mapId, diff = resolveSession()
	workspace:SetAttribute("Map", mapId)
	workspace:SetAttribute("Difficulty", diff.id)
	workspace:SetAttribute("Blind", diff.blind == true)
	Remotes.RoundUpdate:FireAllClients("intro", mapId, diff.id)
	for i = R.WaitForPlayers, 1, -1 do
		workspace:SetAttribute("TimeLeft", i)
		Remotes.RoundUpdate:FireAllClients("waiting", i)
		task.wait(1)
	end

	round = { players = {}, fuses = 0, gensDone = 0, gensNeeded = 0, start = os.clock(), ended = false, mapId = mapId, difficulty = diff }
	round.gensNeeded = resetMap(mapId, diff)
	for _, player in ipairs(Players:GetPlayers()) do
		round.players[player] = { alive = true, escaped = false, fuses = 0, generators = 0, coins = 0, xp = 0, joined = os.clock() }
		player:SetAttribute("Battery", 100)
		player:SetAttribute("Fuses", 0)
		player:SetAttribute("Notes", "")
		player:SetAttribute("FlashlightOn", false)
		player:SetAttribute("AlreadySaved", nil)
		local spare = player:GetAttribute("Perk_battery")
		player:SetAttribute("SpareBatteries", type(spare) == "number" and spare or 0)
		task.spawn(spawnCharacter, player)
	end
	workspace:SetAttribute("RoundState", "Playing")
	local mapCfg = Config.getMap(mapId)
	message(string.format("%s · %s\nГЕНЕРАТОРОВ НУЖНО: %d. НЕ ШУМИ.", mapCfg.name, diff.name, round.gensNeeded), Color3.fromRGB(235, 225, 215))

	ai = spawnMonster(diff)
	local woke = false
	local timeLimit = diff.timeLimit or R.TimeLimit
	while true do
		task.wait(0.25)
		local elapsed = os.clock() - round.start
		local left = math.max(0, timeLimit - elapsed)
		workspace:SetAttribute("TimeLeft", math.floor(left))

		if not woke and elapsed >= (diff.wakeDelay or R.MonsterWakeDelay) and ai then
			woke = true
			ai:wake()
			message(diff.blind and "ОНО ПРОСНУЛОСЬ. ОНО СЛЕПОЕ. ОНО СЛУШАЕТ." or "ОНО ПРОСНУЛОСЬ. НЕ СВЕТИ ЕМУ В ГЛАЗА.", Color3.fromRGB(255, 40, 40))
		end

		-- побег
		if workspace:GetAttribute("Power") then
			local zones = exitZones()
			for player, s in pairs(round.players) do
				if s.alive and not s.escaped then
					local char = player.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					if hrp then
						for _, zone in ipairs(zones) do
							local rel = zone.CFrame:PointToObjectSpace(hrp.Position)
							local half = zone.Size / 2
							if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y + 4 and math.abs(rel.Z) <= half.Z then
								s.escaped = true
								player:SetAttribute("Escaped", true)
								FS.setOn(player, false)
								message(player.DisplayName .. " выбрался наружу!", Color3.fromRGB(110, 220, 110))
								if char then
									char:Destroy()
								end
								break
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
	message(anyEscaped and "РАУНД ОКОНЧЕН. КТО-ТО ВЫБРАЛСЯ." or "НИКТО НЕ ВЫШЕЛ.", Color3.fromRGB(255, 60, 60))
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
