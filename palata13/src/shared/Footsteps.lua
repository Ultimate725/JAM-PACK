--[[
	Шаги персонажей (клиент): звук по материалу пола, ритм по скорости, громкость по режиму
	(присед / шаг / бег). Звучат шаги всех игроков в 3D, с эхом группы SoundService.Master.SFX.Footsteps.
	Стандартные шаги Roblox отключены пустым скриптом StarterPlayerScripts.RbxCharacterSounds.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Sound = require(script.Parent.Sound)

local Footsteps = {}

local SOFT = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Mud] = true,
	[Enum.Material.Sand] = true,
	[Enum.Material.Snow] = true,
	[Enum.Material.Fabric] = true,
}
local WOOD = { [Enum.Material.Wood] = true, [Enum.Material.WoodPlanks] = true }
local METAL = {
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.CorrodedMetal] = true,
	[Enum.Material.Foil] = true,
}

local function keyFor(material)
	if SOFT[material] then
		return "FootstepGrass"
	elseif WOOD[material] then
		return "FootstepWood"
	elseif METAL[material] then
		return "FootstepMetal"
	end
	return "FootstepConcrete"
end

local timers = {} -- [character] = seconds until next step
local side = {}

local function step(player, char, hum, hrp, speed)
	local crouch = player:GetAttribute("Crouching") == true
	local sprint = player:GetAttribute("Sprinting") == true
	local vol = crouch and 0.18 or (sprint and 0.95 or 0.55)
	side[char] = not side[char]
	Sound.play(keyFor(hum.FloorMaterial), hrp, {
		Volume = vol * (0.9 + math.random() * 0.2),
		PlaybackSpeed = (crouch and 0.92 or 1) * (0.92 + math.random() * 0.16) * (side[char] and 1 or 0.96),
		RollOffMinDistance = crouch and 3 or 6,
		RollOffMaxDistance = crouch and 20 or (sprint and 90 or 50),
	})
end

local started = false
function Footsteps.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(function(dt)
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 then
				local v = hrp.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				local moving = speed > 2 and hum.FloorMaterial ~= Enum.Material.Air
				if moving and not player:GetAttribute("Hiding") and not player:GetAttribute("Repairing") then
					-- примерно 2.6 шага/с при ходьбе, чаще на бегу, реже в присяде
					local interval = math.clamp(5.0 / speed, 0.24, 0.75)
					timers[char] = (timers[char] or interval * 0.5) - dt
					if timers[char] <= 0 then
						timers[char] = interval
						step(player, char, hum, hrp, speed)
					end
				else
					timers[char] = nil
				end
			end
		end
		for char in pairs(timers) do
			if not char.Parent then
				timers[char] = nil
				side[char] = nil
			end
		end
	end)
end

return Footsteps
