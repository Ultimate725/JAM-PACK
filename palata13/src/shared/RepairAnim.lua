--[[
	Анимация починки генератора (клиент, без загрузки анимаций на сайт):
	  - от третьего лица: каждый игрок с атрибутом Repairing встаёт на колено у панели,
	    левая рука упирается в корпус, правая крутит ключ (трещотка) — видно всем клиентам;
	  - от первого лица: у себя на экране — ключ в руке перед камерой, рывки трещотки,
	    камера опущена (на колене) и вздрагивает на каждом щелчке.
	Работает через Motor6D.C0 поверх стандартного Animator (R15 и R6).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RepairAnim = {}
RepairAnim.kneelOffset = -0.75 -- насколько опускать камеру у себя
RepairAnim.onRatchet = nil -- function() на каждый щелчок ключа (для тряски камеры)

local A = CFrame.Angles
local bases = {} -- [Motor6D] = исходный C0 (снят при появлении персонажа)
local posed = {} -- [character] = true, пока на нём поза

local function remember(char)
	for _, m in ipairs(char:GetDescendants()) do
		if m:IsA("Motor6D") and bases[m] == nil then
			bases[m] = m.C0
		end
	end
	char.DescendantAdded:Connect(function(m)
		if m:IsA("Motor6D") and bases[m] == nil then
			bases[m] = m.C0
		end
	end)
end

-- ratchet: быстрый рывок вперёд (0..0.35 цикла), медленный возврат
local function ratchet(t)
	local c = t % 0.55 / 0.55
	if c < 0.3 then
		return math.sin(c / 0.3 * math.pi / 2)
	end
	return 1 - (c - 0.3) / 0.7
end

local POSE_R15 = function(t)
	local r = ratchet(t)
	local breathe = math.sin(t * 2.4) * 0.03
	return {
		Root = CFrame.new(0, -0.3, 0) * A(-0.12, 0, 0),
		Waist = A(-0.38 - breathe, 0.1 * r, 0),
		Neck = A(-0.45 + breathe, -0.15 + 0.1 * r, 0),
		RightHip = A(1.45, 0, 0), -- правая нога: ступня впереди
		RightKnee = A(-1.5, 0, 0),
		RightAnkle = A(0.1, 0, 0),
		LeftHip = A(0.15, 0, 0), -- левое колено на полу
		LeftKnee = A(-1.6, 0, 0),
		LeftAnkle = A(0.7, 0, 0),
		LeftShoulder = A(1.15, 0, 0.25), -- левая рука упирается в корпус
		LeftElbow = A(0.35, 0, 0),
		RightShoulder = A(0.95 + 0.45 * r, 0, -0.15 - 0.15 * r), -- правая рука крутит ключ
		RightElbow = A(0.85 - 0.5 * r, 0, 0),
		RightWrist = A(0, 0.6 * r - 0.3, 0),
	}
end

local POSE_R6 = function(t)
	local r = ratchet(t)
	return {
		RootJoint = CFrame.new(0, -1.1, 0) * A(-0.3, 0, 0),
		Neck = A(0.4, 0, 0),
		["Right Hip"] = A(0, 0, 1.4),
		["Left Hip"] = A(0, 0, -0.2),
		["Left Shoulder"] = A(0, 0, -1.2),
		["Right Shoulder"] = A(0, 0, 1.0 + 0.5 * r),
	}
end

local function applyPose(char, t)
	local pose = char:FindFirstChild("UpperTorso") and POSE_R15(t) or POSE_R6(t)
	for _, m in ipairs(char:GetDescendants()) do
		if m:IsA("Motor6D") and pose[m.Name] and bases[m] then
			m.C0 = bases[m] * pose[m.Name]
		end
	end
	posed[char] = true
end

local function clearPose(char)
	for _, m in ipairs(char:GetDescendants()) do
		if m:IsA("Motor6D") and bases[m] then
			m.C0 = bases[m]
		end
	end
	posed[char] = nil
end

-- ключ в руке от первого лица
local viewmodel = nil
local function buildViewmodel()
	local m = Instance.new("Model")
	m.Name = "RepairViewmodel"
	local function part(name, size, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = m
		return p
	end
	part("Glove", Vector3.new(0.55, 0.5, 0.75), Color3.fromRGB(46, 42, 38), Enum.Material.Fabric)
	part("Sleeve", Vector3.new(0.6, 0.6, 1.6), Color3.fromRGB(150, 160, 150), Enum.Material.Fabric)
	part("Handle", Vector3.new(0.18, 0.18, 1.5), Color3.fromRGB(140, 140, 136), Enum.Material.Metal)
	part("Head", Vector3.new(0.5, 0.18, 0.45), Color3.fromRGB(120, 120, 118), Enum.Material.Metal)
	part("Grip", Vector3.new(0.22, 0.22, 0.6), Color3.fromRGB(150, 30, 30), Enum.Material.SmoothPlastic)
	local light = Instance.new("PointLight")
	light.Range = 5
	light.Brightness = 0.6
	light.Color = Color3.fromRGB(255, 200, 140)
	light.Parent = m.Glove
	return m
end

local function placeViewmodel(cam, t)
	local r = ratchet(t)
	local base = cam.CFrame * CFrame.new(0.55, -0.85, -1.7) * A(0.25, -0.15, 0)
	-- рывок: кисть проворачивает ключ вокруг оси головки
	local crank = base * A(0, 0, -0.9 * r + 0.3) * CFrame.new(0, 0.05 * r, 0)
	local m = viewmodel
	m.Glove.CFrame = crank * CFrame.new(0, 0, 0.35)
	m.Sleeve.CFrame = crank * CFrame.new(0.05, -0.1, 1.3) * A(0.12, 0, 0)
	m.Grip.CFrame = crank * CFrame.new(0, 0, 0.35)
	m.Handle.CFrame = crank * CFrame.new(0, 0, -0.35)
	m.Head.CFrame = crank * CFrame.new(0, 0, -1.15)
end

local started = false
function RepairAnim.start()
	if started then
		return
	end
	started = true
	local me = Players.LocalPlayer
	local function watch(p)
		if p.Character then
			remember(p.Character)
		end
		p.CharacterAdded:Connect(remember)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)

	local lastClick = 0
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			if char and char.Parent then
				if p:GetAttribute("Repairing") then
					applyPose(char, t)
				elseif posed[char] then
					clearPose(char)
				end
			end
		end
		for char in pairs(posed) do
			if not char.Parent then
				posed[char] = nil
			end
		end
		for m in pairs(bases) do
			if not m.Parent then
				bases[m] = nil
			end
		end

		local cam = workspace.CurrentCamera
		local mine = me:GetAttribute("Repairing") and cam and not me:GetAttribute("Dead")
		if mine then
			if not viewmodel then
				viewmodel = buildViewmodel()
				viewmodel.Parent = cam
			end
			placeViewmodel(cam, t)
			local phase = t % 0.55 / 0.55
			if phase < 0.05 and t - lastClick > 0.3 then
				lastClick = t
				if RepairAnim.onRatchet then
					RepairAnim.onRatchet()
				end
			end
		elseif viewmodel then
			viewmodel:Destroy()
			viewmodel = nil
		end
	end)
end

return RepairAnim
