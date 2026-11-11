--[[
	Процедурные анимации Пациента 13 (клиент):
	- ходьба / бег с рваной походкой (хромание, длинные руки волочатся)
	- дыхание в покое, дёрганья головы, подёргивание пальцев
	- режим погони: наклон вперёд, руки тянутся к жертве, челюсть открыта
	- атака: пасть раскрывается настежь, руки вверх
	- звуки шагов из стоп + тряска камеры рядом
	Работает через Motor6D.C0 (без загрузки анимаций на сайт).
]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Sound = require(script.Parent.Sound)

local Animator = {}
Animator.onFootstep = nil -- function(position, intensity)

local tracked = {}
local clock = os.clock

local function noise(t, seed)
	return math.noise(t, seed or 0, 0)
end

local function collectJoints(model)
	local joints = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			joints[d.Name] = { motor = d, base = d.C0 }
		end
	end
	return joints
end

function Animator.track(model)
	if tracked[model] then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local joints = collectJoints(model)
	local st = {
		model = model,
		root = root,
		joints = joints,
		phase = 0,
		walk = 0,
		lastSide = 0,
		headTarget = Vector3.zero,
		headCurrent = Vector3.zero,
		nextTwitch = clock() + 1,
		jaw = 0,
		lean = 0,
		reach = 0,
		seed = math.random() * 100,
		footL = model:FindFirstChild("LFoot", true),
		footR = model:FindFirstChild("RFoot", true),
		blind = model:GetAttribute("Blind") == true,
		sniffUntil = 0,
		sonarUntil = 0,
		listen = 0,
		eyes = {},
		dust = nil,
		rage = nil,
	}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("PointLight") and d.Parent and d.Parent.Name == "Eye" then
			table.insert(st.eyes, d)
		elseif d:IsA("ParticleEmitter") and d.Name == "Dust" then
			st.dust = d
		elseif d:IsA("PointLight") and d.Name == "Rage" then
			st.rage = d
		end
	end
	model:GetAttributeChangedSignal("Sniff"):Connect(function()
		st.sniffUntil = clock() + 1.6
		st.listen = (math.random() < 0.5) and -1 or 1
	end)
	model:GetAttributeChangedSignal("Sonar"):Connect(function()
		st.sonarUntil = clock() + 1.1
	end)
	model:GetAttributeChangedSignal("Blind"):Connect(function()
		st.blind = model:GetAttribute("Blind") == true
	end)
	tracked[model] = st
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			tracked[model] = nil
		end
	end)
end

local function set(st, name, cf)
	local j = st.joints[name]
	if j then
		j.motor.C0 = j.base * cf
	end
end

local A = CFrame.Angles

local function step(st, dt)
	local now = clock()
	local state = st.model:GetAttribute("State") or "Patrol"
	local vel = st.root.AssemblyLinearVelocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local moving = math.clamp(speed / 9, 0, 1.6)
	st.walk += (moving - st.walk) * math.min(dt * 6, 1)
	local w = st.walk

	-- частота шага растёт со скоростью
	st.phase += dt * (2.2 + speed * 0.32)
	local p = st.phase
	local s = math.sin(p)
	local c = math.cos(p)

	local chasing = state == "Chase"
	local attacking = state == "Attack"
	local leanTarget = chasing and -0.38 or (attacking and 0.15 or -0.08)
	st.lean += (leanTarget - st.lean) * math.min(dt * 4, 1)
	local reachTarget = chasing and 1 or (attacking and 1.4 or 0)
	st.reach += (reachTarget - st.reach) * math.min(dt * 5, 1)
	local jawTarget = attacking and 1 or (chasing and 0.55 or 0.08 + 0.06 * math.sin(now * 1.7))
	st.jaw += (jawTarget - st.jaw) * math.min(dt * (attacking and 18 or 6), 1)

	local breath = math.sin(now * (chasing and 5 or 1.6)) * 0.035
	local limp = 0.2 -- асимметрия походки: правая нога "хромает"

	-- таз / корпус
	local bob = -math.abs(s) * 0.32 * w
	set(st, "RootJoint", CFrame.new(0, bob, 0) * A(st.lean * 0.4, s * 0.12 * w, s * 0.09 * w))
	set(st, "Waist", A(st.lean + breath - math.abs(c) * 0.06 * w, -s * 0.22 * w, -s * 0.06 * w))

	-- голова: резкие неестественные дёрганья
	if now > st.nextTwitch then
		st.nextTwitch = now + (chasing and 0.25 or 0.5) + math.random() * (chasing and 0.6 or 2.2)
		st.headTarget = Vector3.new((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.9, (math.random() - 0.5) * 1.3)
	end
	local sniffing = now < st.sniffUntil
	local sonar = now < st.sonarUntil
	if sniffing then
		-- прислушивается: голова набок, ухом вперёд, мелкая дрожь
		st.headTarget = Vector3.new(0.15, st.listen * 1.1, st.listen * 0.7)
	elseif sonar then
		st.headTarget = Vector3.new(-0.9, 0, 0) -- запрокидывает голову для крика
	elseif st.blind and not chasing then
		-- слепой постоянно "сканирует" ушами
		st.headTarget = Vector3.new(0.1 + noise(now * 0.7, st.seed + 40) * 0.3, noise(now * 0.5, st.seed + 41) * 1.6, noise(now * 0.6, st.seed + 42) * 0.8)
	end
	st.headCurrent = st.headCurrent:Lerp(st.headTarget, math.min(dt * (sniffing and 30 or 22), 1)) -- очень быстрый рывок
	local hc = st.headCurrent
	local shiver = noise(now * 9, st.seed) * (sniffing and 0.12 or 0.05)
	set(st, "NeckBase", A(-st.lean * 0.6 + 0.1, hc.Y * 0.3, 0))
	set(st, "Neck", A(hc.X - st.lean * 0.5 + shiver, hc.Y, hc.Z + shiver))

	-- челюсть (при эхо-крике пасть раскрыта до предела)
	local tremble = (chasing or attacking) and noise(now * 30, st.seed + 3) * 0.08 or 0
	local jawOpen = sonar and 1.3 or st.jaw
	set(st, "Jaw", A(-jawOpen * 0.85 + tremble, 0, 0))

	-- глаза и "ярость"
	local eyeBright = attacking and 3 or (chasing and 1.8 or 0.35)
	for _, e in ipairs(st.eyes) do
		e.Brightness = eyeBright + noise(now * 6, st.seed + 50) * 0.2
	end
	if st.rage then
		st.rage.Brightness = (st.model:GetAttribute("Enraged") and 0.8 or 0) + (attacking and 1.5 or 0)
	end
	if st.dust then
		st.dust.Enabled = w > 0.3
		st.dust.Rate = 6 + w * 10
	end

	-- ноги (колени согнуты, шаг широкий)
	local legSwing = 0.65 * w
	local function leg(side, ph, amp)
		local sp = math.sin(ph)
		local lift = math.max(0, math.cos(ph))
		set(st, side .. "Hip", A(sp * legSwing * amp + 0.1, 0, 0))
		set(st, side .. "Knee", A(-(lift * 1.0 * w + 0.05), 0, 0))
		set(st, side .. "Ankle", A(-sp * 0.35 * w + lift * 0.4 * w, 0, 0))
	end
	leg("L", p, 1)
	leg("R", p + math.pi, 1 - limp)

	-- руки: длинные, болтаются с запаздыванием; в погоне тянутся вперёд
	local r = st.reach
	local function arm(side, ph, sign)
		local sw = math.sin(ph - 0.5) * 0.55 * w
		local twitch = noise(now * 3, st.seed + (sign > 0 and 10 or 20)) * 0.12
		set(st, side .. "Shoulder", A(-sw + r * 1.15 + twitch, 0, sign * (0.12 + r * 0.15)))
		set(st, side .. "Elbow", A(0.25 + math.max(0, -math.sin(ph)) * 0.35 * w + r * 0.3, 0, 0))
		set(st, side .. "Wrist", A(0.15 + twitch * 2 - r * 0.4, 0, 0))
		for i = 1, 4 do
			local fn = noise(now * (attacking and 12 or 4), st.seed + i * 7 + sign * 3)
			local curl = 0.25 + fn * 0.35 - r * 0.2
			set(st, side .. "F" .. i .. "a", A(curl, 0, 0))
			set(st, side .. "F" .. i .. "b", A(curl * 1.3, 0, 0))
		end
	end
	arm("L", p + math.pi, -1)
	arm("R", p, 1)

	-- шаги: каждые полпериода одна нога бьёт о пол
	local side = s >= 0 and 1 or -1
	if side ~= st.lastSide then
		st.lastSide = side
		if w > 0.25 then
			local foot = side > 0 and st.footR or st.footL
			local pos = foot and foot.Position or st.root.Position
			Sound.play("MonsterStep", foot or st.root, {
				Volume = 0.6 + 0.5 * math.min(w, 1.4),
				PlaybackSpeed = 0.85 + math.random() * 0.2,
				RollOffMinDistance = 10,
				RollOffMaxDistance = 110,
			})
			if Animator.onFootstep then
				Animator.onFootstep(pos, w)
			end
		end
	end
end

local started = false
function Animator.start()
	if started then
		return
	end
	started = true
	RunService.RenderStepped:Connect(function(dt)
		for model, st in pairs(tracked) do
			if model.Parent and st.root.Parent then
				step(st, dt)
			else
				tracked[model] = nil
			end
		end
	end)
end

-- камера трясётся от шагов рядом
function Animator.shakeAmountFor(position)
	local cam = workspace.CurrentCamera
	if not cam then
		return 0
	end
	local d = (cam.CFrame.Position - position).Magnitude
	return math.clamp(1 - d / 35, 0, 1)
end

local _ = Players
return Animator
