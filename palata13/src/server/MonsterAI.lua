--[[
	ИИ Пациента 13.
	Состояния: Sleep -> Patrol -> Investigate (услышал) -> Chase (засёк) -> Search (потерял) -> Attack
	Восприятие зависит от сложности (Config.Difficulties):
	  - blind = true  : не видит вообще. Слышит шаги (радиус зависит от присядки/шага/бега),
	                    щелчок фонарика, шкафчики и генераторы (события шума). Чувствует вплотную (sense).
	  - blind = false : видит (дальше, если у игрока включён фонарик) И слышит.
	  - sonar > 0     : каждые N секунд эхо-крик — выдаёт всех, кто в этот момент двигается.
	- игроки в шкафчиках невидимы, если монстр не видел/не слышал, как они туда залезли
	- с каждым генератором быстрее, после включения света — в ярости
]]
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sound = require(ReplicatedStorage.Shared.Sound)
local Remotes = require(ServerScriptService.Core.Remotes)

local C = Config.Monster

local AI = {}
AI.__index = AI

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

function AI.new(model, map, opts)
	local self = setmetatable({}, AI)
	self.model = model
	self.hum = model:FindFirstChildOfClass("Humanoid")
	self.root = model:FindFirstChild("HumanoidRootPart")
	self.head = model:FindFirstChild("Head") or self.root
	self.map = map
	self.opts = opts or {}
	self.diff = self.opts.difficulty or Config.getDifficulty("Medium")
	self.state = "Sleep"
	self.target = nil
	self.lastSeen = 0
	self.lastSeenPos = nil
	self.investigatePos = nil
	self.investigatePriority = 0
	self.searchUntil = 0
	self.enraged = false
	self.generators = 0
	self.alive = true
	self.exposed = {}
	self.cooldownUntil = 0
	self.lastScream = 0
	self.lastSonar = os.clock()
	self.lastSniff = 0
	self.patrolGoal = nil
	self.waypoints = nil
	self.wpIndex = 1
	self.pathDest = nil
	self.pathTime = 0
	self.lastPos = self.root.Position
	self.lastStuckCheck = os.clock()
	self.stuckCount = 0

	self.nodes = {}
	local nodesFolder = map:FindFirstChild("AINodes")
	if nodesFolder then
		for _, n in ipairs(nodesFolder:GetChildren()) do
			if n:IsA("BasePart") then
				table.insert(self.nodes, n.Position)
			end
		end
	end

	self.path = PathfindingService:CreatePath({
		AgentRadius = 2.6,
		AgentHeight = 10,
		AgentCanJump = false,
		WaypointSpacing = 6,
	})

	self.ray = RaycastParams.new()
	self.ray.FilterType = Enum.RaycastFilterType.Exclude
	self.ray.RespectCanCollide = true

	self.hum.WalkSpeed = 0
	self.hum.AutoRotate = true
	model:SetAttribute("State", "Sleep")
	model:SetAttribute("Blind", self.diff.blind == true)
	model:SetAttribute("Difficulty", self.diff.id)

	-- дыхание (3D, слышно из-за угла)
	self.breath = Sound.make("MonsterBreath", self.head, {
		Looped = true,
		Volume = 0.6,
		RollOffMinDistance = 6,
		RollOffMaxDistance = 70,
	})
	if self.breath then
		self.breath:Play()
	end

	-- шум от действий игроков (фонарик, шкафчики, генераторы)
	if self.opts.noiseSignal then
		self.noiseConn = self.opts.noiseSignal:Connect(function(player, position, kind)
			self:onNoise(player, position, kind)
		end)
	end
	return self
end

function AI:setState(s)
	if self.state == s then
		return
	end
	self.state = s
	self.model:SetAttribute("State", s)
	if self.breath then
		self.breath.PlaybackSpeed = (s == "Chase") and 1.35 or 1
		self.breath.Volume = (s == "Chase") and 1 or 0.6
	end
end

function AI:refreshFilter()
	local list = { self.model }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local lf = workspace:FindFirstChild("LocalFlashlight")
	if lf then
		table.insert(list, lf)
	end
	local pickups = workspace:FindFirstChild("Pickups")
	if pickups then
		table.insert(list, pickups)
	end
	self.ray.FilterDescendantsInstances = list
end

function AI:isCandidate(player)
	if self.opts.isAlive and not self.opts.isAlive(player) then
		return false
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return false
	end
	return true, hrp
end

function AI:eye()
	return self.head.Position
end

function AI:lineClear(fromPos, toPos)
	local dir = toPos - fromPos
	if dir.Magnitude < 0.1 then
		return true
	end
	local hit = workspace:Raycast(fromPos, dir, self.ray)
	return hit == nil
end

-- радиус, на котором слышно шаги игрока прямо сейчас (0 = стоит на месте и молчит)
function AI:noiseRadius(player, hrp)
	local hear = self.diff.hear
	local vel = flat(hrp.AssemblyLinearVelocity).Magnitude
	local r
	if player:GetAttribute("Sprinting") and vel > 4 then
		r = hear.sprint
	elseif player:GetAttribute("Crouching") then
		r = (vel > 1) and hear.crouch or 0
	elseif vel > 1 then
		r = hear.walk
	else
		r = 0
	end
	local perk = player:GetAttribute("Perk_noise")
	if type(perk) == "number" then
		r *= perk
	end
	if self.enraged then
		r *= 1.25
	end
	return r
end

function AI:canSee(player)
	if self.diff.blind then
		return false
	end
	local ok, hrp = self:isCandidate(player)
	if not ok then
		return false
	end
	if player:GetAttribute("Hiding") and not self.exposed[player] then
		return false
	end
	local eye = self:eye()
	local targetPos = hrp.Position + Vector3.new(0, 1.2, 0)
	local toT = targetPos - eye
	local dist = toT.Magnitude
	local range = player:GetAttribute("FlashlightOn") and self.diff.flashlightSight or self.diff.sight
	if self.enraged then
		range += 30
	end
	if player:GetAttribute("Crouching") then
		range *= 0.75 -- в присяде тебя сложнее заметить за мебелью
	end
	if dist > range then
		return false
	end
	if dist > 14 then
		local look = flat(self.root.CFrame.LookVector)
		local d = flat(toT)
		if look.Magnitude > 0 and d.Magnitude > 0 then
			local ang = math.deg(math.acos(math.clamp(look.Unit:Dot(d.Unit), -1, 1)))
			if ang > self.diff.fov / 2 then
				return false
			end
		end
	end
	if player:GetAttribute("Hiding") then
		return true -- видел, как залез в шкаф
	end
	return self:lineClear(eye, targetPos)
end

-- слышит ли шаги игрока (и чувствует ли вплотную)
function AI:canHear(player)
	local ok, hrp = self:isCandidate(player)
	if not ok then
		return false
	end
	if player:GetAttribute("Hiding") and not self.exposed[player] then
		return false
	end
	local dist = (hrp.Position - self.root.Position).Magnitude
	if dist <= self.diff.sense and math.abs(hrp.Position.Y - self.root.Position.Y) < 8 then
		return true -- дыхание в упор
	end
	local r = self:noiseRadius(player, hrp)
	return r > 0 and dist <= r
end

-- одиночный шум (щелчок, дверца, генератор)
function AI:onNoise(player, position, kind)
	if not self.alive or self.state == "Sleep" or self.state == "Attack" then
		return
	end
	local range = self.diff.hear[kind] or 0
	if range <= 0 then
		return
	end
	local perk = player and player:GetAttribute("Perk_noise")
	if type(perk) == "number" then
		range *= perk
	end
	local d = (position - self.root.Position).Magnitude
	if d > range then
		return
	end
	if self.state == "Chase" then
		return
	end
	local priority = (kind == "interact") and 2 or 1
	if self.state ~= "Investigate" or priority >= self.investigatePriority then
		self.investigatePos = position
		self.investigatePriority = priority
		self:setState("Investigate")
		self:sniff()
	end
end

function AI:notifyHide(player)
	if self.target == player and os.clock() - self.lastSeen < 1.5 then
		self.exposed[player] = true
	else
		self.exposed[player] = nil
	end
end

function AI:notifyUnhide(player)
	self.exposed[player] = nil
end

function AI:speedFor(state)
	local sp = self.diff.speed
	local bonus = self.generators * C.ChaseSpeedPerGenerator + (self.enraged and C.EnragedBonus or 0)
	if state == "Chase" then
		return sp.chase + bonus
	elseif state == "Investigate" or state == "Search" then
		return sp.investigate + bonus * 0.5
	end
	return sp.patrol + bonus * 0.3
end

function AI:computePath(dest)
	local ok = pcall(function()
		self.path:ComputeAsync(self.root.Position, dest)
	end)
	self.pathTime = os.clock()
	self.pathDest = dest
	if ok and self.path.Status == Enum.PathStatus.Success then
		self.waypoints = self.path:GetWaypoints()
		self.wpIndex = math.min(2, #self.waypoints)
		return true
	end
	self.waypoints = nil
	return false
end

-- движение к точке; возвращает true, когда дошёл
function AI:moveTowards(dest, repathEvery)
	local pos = self.root.Position
	if (flat(dest) - flat(pos)).Magnitude < 4 then
		return true
	end
	-- прямая видимость — идём напрямую (быстрее и страшнее)
	local destAtRoot = Vector3.new(dest.X, pos.Y, dest.Z)
	local right = self.root.CFrame.RightVector * 2.4
	if (destAtRoot - pos).Magnitude < 70
		and self:lineClear(pos, destAtRoot)
		and self:lineClear(pos + Vector3.new(0, 3.5, 0), destAtRoot + Vector3.new(0, 3.5, 0))
		and self:lineClear(pos + right, destAtRoot + right)
		and self:lineClear(pos - right, destAtRoot - right)
	then
		self.waypoints = nil
		self.hum:MoveTo(dest)
		return false
	end
	if
		not self.waypoints
		or not self.pathDest
		or (self.pathDest - dest).Magnitude > 6
		or os.clock() - self.pathTime > (repathEvery or 2)
	then
		if not self:computePath(dest) then
			self.hum:MoveTo(dest)
			return false
		end
	end
	local wp = self.waypoints[self.wpIndex]
	while wp and (flat(wp.Position) - flat(self.root.Position)).Magnitude < 3.5 do
		self.wpIndex += 1
		wp = self.waypoints[self.wpIndex]
	end
	if not wp then
		self.waypoints = nil
		return true
	end
	self.hum:MoveTo(wp.Position)
	return false
end

function AI:pickPatrolGoal()
	if #self.nodes == 0 then
		return self.root.Position
	end
	-- иногда он "чувствует" игрока и идёт в его сторону
	if math.random() < (self.enraged and 0.8 or C.HuntChance) then
		local candidates = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local ok, hrp = self:isCandidate(p)
			if ok then
				table.insert(candidates, hrp.Position)
			end
		end
		if #candidates > 0 then
			local target = candidates[math.random(1, #candidates)]
			local best, bestD = nil, math.huge
			for _, n in ipairs(self.nodes) do
				local d = (n - target).Magnitude + math.random() * 40
				if d < bestD then
					best, bestD = n, d
				end
			end
			if best then
				return best
			end
		end
	end
	return self.nodes[math.random(1, #self.nodes)]
end

function AI:scream()
	if os.clock() - self.lastScream > 18 then
		self.lastScream = os.clock()
		Sound.play("MonsterScream", self.head, {
			Volume = 0.9,
			PlaybackSpeed = 1.15,
			RollOffMinDistance = 12,
			RollOffMaxDistance = 160,
		})
	end
end

function AI:sniff()
	if os.clock() - self.lastSniff > 4 then
		self.lastSniff = os.clock()
		self.model:SetAttribute("Sniff", os.clock())
		Sound.play("MonsterSniff", self.head, { Volume = 0.8, RollOffMinDistance = 8, RollOffMaxDistance = 80 })
	end
end

-- ЭХО-КРИК (режим Кошмар): выдаёт всех, кто двигается
function AI:sonar()
	self.lastSonar = os.clock()
	self.model:SetAttribute("Sonar", os.clock())
	Sound.play("Sonar", self.head, { Volume = 1.2, RollOffMinDistance = 20, RollOffMaxDistance = 400 })
	Remotes.Sonar:FireAllClients(self.root.Position)
	task.delay(0.6, function()
		if not self.alive then
			return
		end
		local best, bestD = nil, math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			local ok, hrp = self:isCandidate(p)
			if ok and not p:GetAttribute("Hiding") then
				local vel = flat(hrp.AssemblyLinearVelocity).Magnitude
				local d = (hrp.Position - self.root.Position).Magnitude
				if vel > 0.8 and d < 180 and d < bestD then
					best, bestD = p, d
				end
			end
		end
		if best and self.state ~= "Attack" then
			local _, hrp = self:isCandidate(best)
			if bestD < 55 then
				self.target = best
				self.lastSeen = os.clock()
				self.lastSeenPos = hrp.Position
				self:setState("Chase")
				self:scream()
			else
				self.investigatePos = hrp.Position
				self.investigatePriority = 3
				self:setState("Investigate")
			end
			Remotes.notify(best, "ОНО УСЛЫШАЛО ТЕБЯ. ЗАМРИ.", Color3.fromRGB(235, 40, 40))
		end
	end)
end

function AI:catch(player)
	local ok, hrp = self:isCandidate(player)
	if not ok then
		return
	end
	self:setState("Attack")
	self.target = nil
	self.hum:MoveTo(self.root.Position)
	player:SetAttribute("Caught", true)
	if player:GetAttribute("Hiding") and self.opts.onDragOut then
		self.opts.onDragOut(player)
	end
	hrp.Anchored = true
	local look = Vector3.new(hrp.Position.X, self.root.Position.Y, hrp.Position.Z)
	if (look - self.root.Position).Magnitude > 0.1 then
		self.root.Anchored = true
		self.root.CFrame = CFrame.lookAt(self.root.Position, look)
	end
	-- жертву разворачиваем лицом к монстру
	local facePos = Vector3.new(self.root.Position.X, hrp.Position.Y, self.root.Position.Z)
	if (facePos - hrp.Position).Magnitude > 0.1 then
		hrp.CFrame = CFrame.lookAt(hrp.Position, facePos)
	end
	Remotes.Jumpscare:FireClient(player, self.model)
	Sound.play("MonsterScream", self.head, { Volume = 1.3, RollOffMinDistance = 15, RollOffMaxDistance = 180 })
	task.wait(2.4)
	if self.opts.onCatch then
		self.opts.onCatch(player)
	end
	self.exposed[player] = nil
	self.root.Anchored = false
	pcall(function()
		self.root:SetNetworkOwner(nil)
	end)
	self.cooldownUntil = os.clock() + 3
	self:setState("Patrol")
	self.patrolGoal = self:pickPatrolGoal()
end

function AI:wake()
	if self.state ~= "Sleep" then
		return
	end
	self:setState("Patrol")
	self:scream()
	pcall(function()
		self.root:SetNetworkOwner(nil)
	end)
	task.spawn(function()
		self:loop()
	end)
end

function AI:hunt()
	-- идёт к ближайшему игроку (после запуска генератора)
	local best, bestD = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		local ok, hrp = self:isCandidate(p)
		if ok and not p:GetAttribute("Hiding") then
			local d = (hrp.Position - self.root.Position).Magnitude
			if d < bestD then
				best, bestD = hrp.Position, d
			end
		end
	end
	if best then
		self.investigatePos = best
		self.investigatePriority = 2
		self:setState("Investigate")
	end
end

function AI:stop()
	self.alive = false
	if self.breath then
		self.breath:Stop()
	end
	if self.noiseConn then
		self.noiseConn:Disconnect()
	end
end

function AI:loseTime(player)
	local t = self.diff.loseTime
	local perk = player and player:GetAttribute("Perk_lose")
	if type(perk) == "number" then
		t *= perk
	end
	return t
end

function AI:loop()
	local filterTick = 0
	while self.alive and self.model.Parent and self.hum.Health > 0 do
		local dt = task.wait(0.1)
		filterTick += dt
		if filterTick > 1 then
			filterTick = 0
			self:refreshFilter()
		end
		if self.state == "Attack" or os.clock() < self.cooldownUntil then
			continue
		end

		if self.diff.sonar > 0 and os.clock() - self.lastSonar > self.diff.sonar then
			self:sonar()
		end

		-- кого видим / слышим
		local seen, seenD, seenHrp = nil, math.huge, nil
		local heardPos, heardD = nil, math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			local ok, hrp = self:isCandidate(p)
			if ok then
				local d = (hrp.Position - self.root.Position).Magnitude
				if self:canSee(p) then
					if d < seenD then
						seen, seenD, seenHrp = p, d, hrp
					end
				elseif self:canHear(p) then
					if self.diff.blind then
						-- слепой: "видит" ушами — преследует источник шума
						if d < seenD then
							seen, seenD, seenHrp = p, d, hrp
						end
					elseif d < heardD then
						heardPos, heardD = hrp.Position, d
					end
				end
			end
		end

		if seen then
			if self.state ~= "Chase" then
				self:scream()
				if self.diff.blind then
					self:sniff()
				end
			end
			self.target = seen
			self.lastSeen = os.clock()
			self.lastSeenPos = seenHrp.Position
			self:setState("Chase")
		elseif heardPos and self.state ~= "Chase" then
			self.investigatePos = heardPos
			self.investigatePriority = 1
			self:setState("Investigate")
			self:sniff()
		end

		local state = self.state
		self.hum.WalkSpeed = self:speedFor(state)

		if state == "Chase" then
			local ok, hrp = false, nil
			if self.target then
				ok, hrp = self:isCandidate(self.target)
			end
			if not ok then
				self.target = nil
				self:setState("Search")
				self.searchUntil = os.clock() + 5
			else
				local d = (hrp.Position - self.root.Position).Magnitude
				local hiddenSafe = self.target:GetAttribute("Hiding") and not self.exposed[self.target]
				if d <= C.KillRange and not hiddenSafe and math.abs(hrp.Position.Y - self.root.Position.Y) < 8 then
					self:catch(self.target)
					continue
				end
				if os.clock() - self.lastSeen > self:loseTime(self.target) or hiddenSafe then
					self.target = nil
					self:setState("Search")
					self.searchUntil = os.clock() + 6
				else
					-- пока засёк — бежит к игроку, потерял — к последней точке (недолго "чует")
					local fresh = self.diff.blind and 0.8 or 2
					local dest = (os.clock() - self.lastSeen < fresh) and hrp.Position or self.lastSeenPos
					self:moveTowards(dest, 0.6)
				end
			end
		elseif state == "Investigate" then
			if not self.investigatePos or self:moveTowards(self.investigatePos, 1.5) then
				self.investigatePriority = 0
				self:setState("Search")
				self.searchUntil = os.clock() + 4
			end
		elseif state == "Search" then
			if self.lastSeenPos and (flat(self.lastSeenPos) - flat(self.root.Position)).Magnitude > 5 then
				if self:moveTowards(self.lastSeenPos, 1.5) then
					self.lastSeenPos = nil
				end
			else
				-- осматривается / прислушивается: резкие повороты на месте
				if math.random() < 0.15 then
					local a = math.random() * math.pi * 2
					self.hum:MoveTo(self.root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * 3)
					if self.diff.blind then
						self:sniff()
					end
				end
			end
			if os.clock() > self.searchUntil then
				self.lastSeenPos = nil
				self:setState("Patrol")
				self.patrolGoal = self:pickPatrolGoal()
			end
		elseif state == "Patrol" then
			if not self.patrolGoal then
				self.patrolGoal = self:pickPatrolGoal()
			end
			if self:moveTowards(self.patrolGoal, 4) then
				self.patrolGoal = self:pickPatrolGoal()
			end
		end

		-- застрял?
		if os.clock() - self.lastStuckCheck > 1.5 then
			local moved = (flat(self.root.Position) - flat(self.lastPos)).Magnitude
			self.lastPos = self.root.Position
			self.lastStuckCheck = os.clock()
			if moved < 1 and self.state ~= "Search" then
				self.stuckCount += 1
				self.waypoints = nil
				if self.stuckCount >= 2 then
					self.stuckCount = 0
					if self.state == "Patrol" or self.state == "Investigate" then
						self:setState("Patrol")
						self.patrolGoal = self:pickPatrolGoal()
					end
					-- небольшой сдвиг назад
					self.hum:MoveTo(self.root.Position - self.root.CFrame.LookVector * 4)
				end
			else
				self.stuckCount = 0
			end
		end
	end
end

return AI
