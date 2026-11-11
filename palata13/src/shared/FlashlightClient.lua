--[[
	Локальный фонарик (клиент). Сервер решает вкл/выкл и батарею (атрибуты игрока),
	а тут красивый луч из камеры: плавное запаздывание, покачивание при ходьбе,
	мерцание при низком заряде и когда Пациент рядом.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FL = {}

function FL.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local action = remotes:WaitForChild("Action")

	local part = Instance.new("Part")
	part.Name = "LocalFlashlight"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Parent = workspace

	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Angle = 50
	beam.Range = 62
	beam.Brightness = 2.6
	beam.Shadows = true
	beam.Parent = part

	local hot = Instance.new("SpotLight")
	hot.Face = Enum.NormalId.Front
	hot.Angle = 20
	hot.Range = 75
	hot.Brightness = 1.6
	hot.Shadows = false
	hot.Parent = part

	local fill = Instance.new("PointLight")
	fill.Range = 7
	fill.Brightness = 0.25
	fill.Shadows = false
	fill.Parent = part

	local api = { part = part, forceFlicker = 0, disabled = false }
	local current = workspace.CurrentCamera.CFrame
	local swayT = 0
	local flickerUntil = 0
	local flickerOn = true

	local function isOn()
		return player:GetAttribute("FlashlightOn") == true and not api.disabled
	end

	local function hideServerBeam(char)
		if not char then
			return
		end
		local function apply(d)
			if d:IsA("Light") and d.Parent and d.Parent.Name == "ServerBeam" then
				d.Brightness = 0
			end
		end
		for _, d in ipairs(char:GetDescendants()) do
			apply(d)
		end
		char.DescendantAdded:Connect(apply)
	end
	hideServerBeam(player.Character)
	player.CharacterAdded:Connect(hideServerBeam)

	function api.toggle()
		action:FireServer("flashlight")
	end

	ContextActionService:BindAction("Flashlight", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			api.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL1)
	ContextActionService:SetTitle("Flashlight", "Фонарь")
	ContextActionService:SetPosition("Flashlight", UDim2.new(1, -200, 1, -150))

	local lastPitchSent = 0
	local lastSend = 0

	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		local on = isOn()
		local color = player:GetAttribute("FlashColor")
		if typeof(color) == "Color3" then
			beam.Color = color
			hot.Color = color
			fill.Color = color
		end
		local big = player:GetAttribute("BigBattery") == true
		beam.Range = big and 78 or 62
		hot.Range = big and 90 or 75

		-- сглаженное следование за камерой + покачивание
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local moveSpeed = hum and hum.MoveDirection.Magnitude * hum.WalkSpeed or 0
		swayT += dt * (1 + moveSpeed * 0.45)
		local swayAmt = 0.012 + moveSpeed * 0.0018
		local sway = CFrame.Angles(math.sin(swayT * 2) * swayAmt, math.sin(swayT) * swayAmt * 1.4, 0)
		local target = cam.CFrame * CFrame.new(0.45, -0.35, -0.2) * sway
		current = current:Lerp(target, math.clamp(dt * 16, 0, 1))
		part.CFrame = current

		-- мерцание
		local battery = player:GetAttribute("Battery") or 100
		local monsterNear = 0
		local monster = workspace:FindFirstChild("Monster")
		if monster and monster:FindFirstChild("HumanoidRootPart") then
			local d = (monster.HumanoidRootPart.Position - cam.CFrame.Position).Magnitude
			monsterNear = math.clamp(1 - d / 32, 0, 1)
		end
		local flickerChance = 0
		if battery < 20 then
			flickerChance += (20 - battery) / 20 * 0.06
		end
		flickerChance += monsterNear * 0.18 + api.forceFlicker
		local now = os.clock()
		if now > flickerUntil then
			if math.random() < flickerChance then
				flickerOn = false
				flickerUntil = now + 0.03 + math.random() * 0.12
			else
				flickerOn = true
			end
		end
		local lit = on and flickerOn
		local dim = (battery < 10) and (0.45 + battery / 20) or 1
		beam.Enabled = lit
		hot.Enabled = lit
		fill.Enabled = lit
		beam.Brightness = 2.6 * dim
		hot.Brightness = 1.6 * dim

		-- отправляем серверу наклон луча, чтобы другие видели, куда ты светишь
		if on and now - lastSend > 0.2 then
			local pitch = math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1))
			if math.abs(pitch - lastPitchSent) > 0.05 then
				lastPitchSent = pitch
				lastSend = now
				action:FireServer("aim", pitch)
			end
		end
	end)

	return api
end

return FL
