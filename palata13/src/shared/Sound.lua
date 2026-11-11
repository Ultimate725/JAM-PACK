-- Проигрывание звуков по ключу из Config.Sounds. Если ID = 0 — тихо пропускаем (без ошибок).
-- Все звуки идут через SoundGroup'ы SoundService.Master -> Music / SFX, чтобы работал ползунок громкости.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)

local Sound = {}

local MUSIC_KEYS = { MenuMusic = true, Ambience = true, AmbienceMorgue = true, AmbienceForest = true, Wind = true }
local STEP_KEYS = { FootstepConcrete = true, FootstepWood = true, FootstepGrass = true, FootstepMetal = true }

local function ensureGroup(parent, name)
	local g = parent:FindFirstChild(name)
	if not g and RunService:IsClient() then
		g = parent:WaitForChild(name, 5) -- группы лежат в плейсе, ждём репликацию
	end
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Volume = 1
		g.Parent = parent
	end
	return g
end

-- группы создаёт сервер (реплицируются), клиент только меняет Volume у себя
local master = ensureGroup(SoundService, "Master")
local musicGroup = ensureGroup(master, "Music")
local sfxGroup = ensureGroup(master, "SFX")
-- шаги идут через свою группу с эхом и реверберацией (вложена в SFX — ползунок эффектов действует)
local stepGroup = ensureGroup(sfxGroup, "Footsteps")
local function ensureEffect(name, className, props)
	local e = stepGroup:FindFirstChild(name)
	if not e and RunService:IsClient() then
		e = stepGroup:WaitForChild(name, 5)
	end
	if not e and RunService:IsServer() then
		e = Instance.new(className)
		e.Name = name
		for k, v in pairs(props) do
			e[k] = v
		end
		e.Parent = stepGroup
	end
	return e
end
local echo = ensureEffect("Echo", "EchoSoundEffect", { Delay = 0.22, Feedback = 0.3, DryLevel = 0, WetLevel = -7, Priority = 1 })
local reverbFx = ensureEffect("Reverb", "ReverbSoundEffect", { DecayTime = 1.6, Density = 1, Diffusion = 1, DryLevel = 0, WetLevel = -9, Priority = 2 })
Sound.groups = { master = master, music = musicGroup, sfx = sfxGroup, steps = stepGroup }

function Sound.id(key)
	local v = Config.Sounds[key]
	if v == nil or v == 0 or v == "" then
		return nil
	end
	if typeof(v) == "number" then
		return "rbxassetid://" .. tostring(v)
	end
	return tostring(v)
end

-- создать Sound (не запуская). parent = часть/аттачмент для 3D, nil = 2D
function Sound.make(key, parent, props)
	local id = Sound.id(key)
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = id
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 90
	s.SoundGroup = MUSIC_KEYS[key] and musicGroup or (STEP_KEYS[key] and stepGroup or sfxGroup)
	if props then
		for k, v in pairs(props) do
			s[k] = v
		end
	end
	s.Parent = parent or SoundService
	return s
end

-- одноразовый звук
function Sound.play(key, parent, props)
	local s = Sound.make(key, parent, props)
	if not s then
		return nil
	end
	if not s.Looped then
		s.Ended:Connect(function()
			s:Destroy()
		end)
		Debris:AddItem(s, 25)
	end
	s:Play()
	return s
end

-- звук в точке пространства
function Sound.playAt(key, position, props)
	if not Sound.id(key) then
		return nil
	end
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	Debris:AddItem(a, 25)
	return Sound.play(key, a, props)
end

-- громкость (клиент): значения 0..1
function Sound.setVolumes(masterV, musicV, sfxV)
	if RunService:IsClient() then
		master.Volume = math.clamp(masterV or 1, 0, 1)
		musicGroup.Volume = math.clamp(musicV or 1, 0, 1)
		sfxGroup.Volume = math.clamp(sfxV or 1, 0, 1)
	end
end

-- эхо шагов под помещение (клиент, локально): "hall" | "tiles" | "outdoor" | "lobby"
local SPACES = {
	hall = { delay = 0.24, feedback = 0.32, wet = -7, decay = 1.8, reverbWet = -9, ambient = Enum.ReverbType.StoneCorridor },
	tiles = { delay = 0.15, feedback = 0.45, wet = -4, decay = 2.6, reverbWet = -6, ambient = Enum.ReverbType.Cave },
	outdoor = { delay = 0.38, feedback = 0.12, wet = -16, decay = 0.9, reverbWet = -16, ambient = Enum.ReverbType.Forest },
	lobby = { delay = 0.2, feedback = 0.28, wet = -8, decay = 1.5, reverbWet = -10, ambient = Enum.ReverbType.Hallway },
}
function Sound.setSpace(name)
	local sp = SPACES[name] or SPACES.hall
	if echo then
		echo.Delay = sp.delay
		echo.Feedback = sp.feedback
		echo.WetLevel = sp.wet
	end
	if reverbFx then
		reverbFx.DecayTime = sp.decay
		reverbFx.WetLevel = sp.reverbWet
	end
	pcall(function()
		SoundService.AmbientReverb = sp.ambient
	end)
end

return Sound
