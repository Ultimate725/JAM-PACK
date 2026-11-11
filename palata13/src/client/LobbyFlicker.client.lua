-- Мигание ламп FlickerLamp в лобби
local RunService = game:GetService("RunService")
local Lobby = workspace:WaitForChild("Lobby")
local folderL = Lobby:WaitForChild("Lights")
local items = {}
for _, p in ipairs(folderL:GetChildren()) do
	if p:IsA("BasePart") and p.Name == "FlickerLamp" then
		local l = p:FindFirstChildWhichIsA("Light")
		if l then
			table.insert(items, { p = p, l = l, b = l.Brightness, c = p.Color, t = math.random() * 3 })
		end
	end
end
RunService.Heartbeat:Connect(function(dt)
	for _, it in ipairs(items) do
		it.t = it.t - dt
		if it.t <= 0 then
			local off = math.random() < 0.45
			it.l.Brightness = off and it.b * 0.05 or it.b * (0.7 + math.random() * 0.4)
			it.p.Color = off and Color3.new(0.12, 0.12, 0.11) or it.c
			it.t = off and (0.03 + math.random() * 0.15) or (0.05 + math.random() * (math.random() < 0.2 and 3 or 0.4))
		end
	end
end)
