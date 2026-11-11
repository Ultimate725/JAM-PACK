--[[
	Серверная часть фонарика: вкл/выкл, батарея, звук щелчка (3D — слышат другие),
	луч "ServerBeam" на голове — его видят другие игроки (и монстр замечает свет).
	У самого игрока он скрыт — ему светит красивый локальный фонарь.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Parent.Remotes)
local Config = require(ReplicatedStorage.Shared.Config)
local Sound = require(ReplicatedStorage.Shared.Sound)

local FS = {}
FS.infinite = false -- в лобби батарея бесконечная
FS.actionHandlers = {} -- доп. обработчики Action (name -> fn(player, ...))

local function beamOf(player)
	local char = player.Character
	return char and char:FindFirstChild("ServerBeam")
end

function FS.setOn(player, on)
	if on and (player:GetAttribute("Battery") or 0) <= 0 then
		on = false
	end
	if player:GetAttribute("FlashlightOn") == on then
		return
	end
	player:SetAttribute("FlashlightOn", on)
	local beam = beamOf(player)
	if beam then
		for _, l in ipairs(beam:GetChildren()) do
			if l:IsA("Light") then
				l.Enabled = on
			end
		end
		Sound.play(on and "FlashlightOn" or "FlashlightOff", beam, { Volume = 0.8, RollOffMaxDistance = 40 })
	end
end

function FS.addBattery(player, amount)
	local b = player:GetAttribute("Battery") or 0
	player:SetAttribute("Battery", math.clamp(b + amount, 0, 100))
end

local function makeBeam(player, char)
	local head = char:WaitForChild("Head", 10)
	if not head then
		return
	end
	local old = char:FindFirstChild("ServerBeam")
	if old then
		old:Destroy()
	end
	local p = Instance.new("Part")
	p.Name = "ServerBeam"
	p.Size = Vector3.new(0.3, 0.3, 0.6)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	local w = Instance.new("Weld")
	w.Name = "AimWeld"
	w.Part0 = head
	w.Part1 = p
	w.C0 = CFrame.new(0.4, 0, -0.6)
	w.Parent = p
	local s = Instance.new("SpotLight")
	s.Face = Enum.NormalId.Front
	s.Angle = 45
	s.Range = 55
	s.Brightness = 2.5
	s.Shadows = true
	s.Enabled = player:GetAttribute("FlashlightOn") == true
	local color = player:GetAttribute("FlashColor")
	if typeof(color) == "Color3" then
		s.Color = color
	end
	s.Parent = p
	p.Parent = char
	player:GetAttributeChangedSignal("FlashColor"):Connect(function()
		local c = player:GetAttribute("FlashColor")
		if typeof(c) == "Color3" and s.Parent then
			s.Color = c
		end
	end)
end

function FS.start(infinite)
	FS.infinite = infinite == true
	local function onPlayer(player)
		player:SetAttribute("Battery", 100)
		player:SetAttribute("FlashlightOn", false)
		player.CharacterAdded:Connect(function(char)
			makeBeam(player, char)
		end)
		if player.Character then
			task.spawn(makeBeam, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end

	Remotes.Action.OnServerEvent:Connect(function(player, name, ...)
		if name == "flashlight" then
			FS.setOn(player, not player:GetAttribute("FlashlightOn"))
		elseif name == "aim" then
			local pitch = ...
			if type(pitch) == "number" and pitch == pitch then
				pitch = math.clamp(pitch, -1.3, 1.3)
				local beam = beamOf(player)
				local weld = beam and beam:FindFirstChild("AimWeld")
				if weld then
					weld.C0 = CFrame.new(0.4, 0, -0.6) * CFrame.Angles(pitch, 0, 0)
				end
			end
		elseif name == "sprint" then
			local on = ...
			player:SetAttribute("Sprinting", on == true)
		else
			local h = FS.actionHandlers[name]
			if h then
				h(player, ...)
			end
		end
	end)

	task.spawn(function()
		local dt = 0.25
		while true do
			task.wait(dt)
			if not FS.infinite then
				for _, player in ipairs(Players:GetPlayers()) do
					if player:GetAttribute("FlashlightOn") then
						local drain = Config.Player.BatteryDrainPerSec * dt
						if player:GetAttribute("BigBattery") then
							drain *= 0.5
						end
						local b = (player:GetAttribute("Battery") or 0) - drain
						if b <= 0 then
							b = 0
							player:SetAttribute("Battery", 0)
							FS.setOn(player, false)
							Remotes.notify(player, "Батарея села. Темнота смотрит на тебя.", Color3.fromRGB(235, 40, 40))
						else
							player:SetAttribute("Battery", b)
						end
					end
				end
			end
		end
	end)
end

return FS
