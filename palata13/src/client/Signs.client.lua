--[[
	Signs: создаёт надписи (SurfaceGui) на деталях, у которых есть StringValue "SignText".
	Стиль берётся из StringValue "SignStyle": plain / room / exit / blood / gold / big.
]]
local STYLES = {
	plain = { color = Color3.fromRGB(215, 208, 190), font = Enum.Font.Antique, stroke = 0.5, light = 1 },
	room = { color = Color3.fromRGB(230, 232, 222), font = Enum.Font.SourceSansSemibold, stroke = 1, light = 1 },
	exit = { color = Color3.fromRGB(130, 255, 160), font = Enum.Font.GothamBold, stroke = 1, light = 0, bright = 2 },
	blood = { color = Color3.fromRGB(125, 6, 8), font = Enum.Font.Antique, stroke = 1, light = 1, rot = true },
	gold = { color = Color3.fromRGB(255, 205, 90), font = Enum.Font.Antique, stroke = 0.4, light = 0, bright = 1.4 },
	big = { color = Color3.fromRGB(190, 182, 160), font = Enum.Font.Antique, stroke = 0.7, light = 1 },
}

local function make(value)
	local part = value.Parent
	if not part or not part:IsA("BasePart") or part:FindFirstChild("SignGui") then
		return
	end
	local styleValue = part:FindFirstChild("SignStyle")
	local style = STYLES[styleValue and styleValue.Value or "plain"] or STYLES.plain
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = style.light
	gui.Brightness = style.bright or 1
	gui.MaxDistance = 160
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = value.Value
	t.TextScaled = true
	t.Font = style.font
	t.TextColor3 = style.color
	t.TextStrokeTransparency = style.stroke
	t.TextStrokeColor3 = Color3.new(0, 0, 0)
	if style.rot then
		t.Rotation = math.random(-5, 5)
	end
	t.Parent = gui
	gui.Parent = part
end

for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("StringValue") and d.Name == "SignText" then
		make(d)
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("StringValue") and d.Name == "SignText" then
		task.defer(make, d)
	end
end)
