-- Клиентская копия данных игрока (монеты, батлпасс, фонарики...)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientData = {}
ClientData.data = nil

local changed = Instance.new("BindableEvent")
ClientData.Changed = changed.Event

local started = false

function ClientData.start()
	if started then
		return
	end
	started = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("DataUpdated").OnClientEvent:Connect(function(data)
		ClientData.data = data
		changed:Fire(data)
	end)
	task.spawn(function()
		local getData = remotes:WaitForChild("GetData")
		for _ = 1, 30 do
			local ok, data = pcall(function()
				return getData:InvokeServer()
			end)
			if ok and data then
				ClientData.data = data
				changed:Fire(data)
				return
			end
			task.wait(1)
		end
	end)
end

function ClientData.get()
	return ClientData.data
end

function ClientData.wait()
	while not ClientData.data do
		ClientData.Changed:Wait()
	end
	return ClientData.data
end

return ClientData
