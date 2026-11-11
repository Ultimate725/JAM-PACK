-- Создаёт все RemoteEvent / RemoteFunction в ReplicatedStorage.Remotes
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
end

local events = { "DataUpdated", "Notify", "Action", "Jumpscare", "RoundUpdate", "Teleporting", "Power", "Results", "Scare" }
local functions = { "GetData", "ShopRequest", "ClaimReward", "UseRevive" }

for _, name in ipairs(events) do
	local e = folder:FindFirstChild(name)
	if not e then
		e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = folder
	end
	Remotes[name] = e
end
for _, name in ipairs(functions) do
	local f = folder:FindFirstChild(name)
	if not f then
		f = Instance.new("RemoteFunction")
		f.Name = name
		f.Parent = folder
	end
	Remotes[name] = f
end

function Remotes.notify(player, text, color)
	Remotes.Notify:FireClient(player, text, color)
end

function Remotes.notifyAll(text, color)
	Remotes.Notify:FireAllClients(text, color)
end

return Remotes
