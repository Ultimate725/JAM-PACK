-- Проигрывание звуков по ключу из Config.Sounds. Если ID = 0 — тихо пропускаем (без ошибок).
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Config = require(script.Parent.Config)

local Sound = {}

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

return Sound
