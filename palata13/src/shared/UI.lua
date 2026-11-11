-- Криповый UI-кит: кнопки с мерцанием, окна, тосты, виньетка
local TweenService = game:GetService("TweenService")
local Sound = require(script.Parent.Sound)

local UI = {}

UI.Colors = {
	Bg = Color3.fromRGB(6, 5, 5),
	Panel = Color3.fromRGB(14, 11, 11),
	Panel2 = Color3.fromRGB(22, 16, 16),
	Red = Color3.fromRGB(150, 14, 14),
	BrightRed = Color3.fromRGB(235, 40, 40),
	Text = Color3.fromRGB(222, 212, 200),
	Dim = Color3.fromRGB(125, 115, 110),
	Gold = Color3.fromRGB(235, 185, 70),
	Green = Color3.fromRGB(110, 200, 110),
}

local function safeFont(name, fallback)
	local ok, f = pcall(function()
		return Enum.Font[name]
	end)
	if ok and f then
		return f
	end
	return fallback
end

-- шрифты с кириллицей
UI.FontTitle = safeFont("Oswald", Enum.Font.SourceSansBold)
UI.FontMono = safeFont("RobotoMono", Enum.Font.Code)
UI.FontText = safeFont("SourceSans", Enum.Font.SourceSans)
UI.FontBold = safeFont("SourceSansBold", Enum.Font.SourceSansBold)

function UI.new(className, props, children)
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.corner(r)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, r or 6) })
end

function UI.stroke(color, thickness, transparency)
	return UI.new("UIStroke", {
		Color = color or UI.Colors.Red,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.padding(px)
	return UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

function UI.tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

function UI.label(props)
	local base = {
		BackgroundTransparency = 1,
		Font = UI.FontText,
		TextColor3 = UI.Colors.Text,
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in pairs(props or {}) do
		base[k] = v
	end
	return UI.new("TextLabel", base)
end

-- жуткая кнопка: мерцает при наведении, текст краснеет
function UI.button(props, onClick)
	local base = {
		AutoButtonColor = false,
		BackgroundColor3 = UI.Colors.Panel2,
		BackgroundTransparency = 0.15,
		Font = UI.FontTitle,
		TextColor3 = UI.Colors.Text,
		TextSize = 20,
		Text = "КНОПКА",
	}
	for k, v in pairs(props or {}) do
		if k ~= "NoStroke" then
			base[k] = v
		end
	end
	local btn = UI.new("TextButton", base)
	if not props or props.NoStroke ~= true then
		UI.stroke(UI.Colors.Red, 1, 0.4).Parent = btn
	end
	local normalColor = btn.TextColor3
	local hovering = false
	btn.MouseEnter:Connect(function()
		hovering = true
		Sound.play("UIHover", nil, { Volume = 0.5, PlaybackSpeed = 0.9 + math.random() * 0.2 })
		UI.tween(btn, 0.12, { TextColor3 = UI.Colors.BrightRed })
		task.spawn(function()
			for _ = 1, 6 do
				if not hovering then
					break
				end
				btn.TextTransparency = math.random() < 0.5 and 0.6 or 0
				task.wait(0.03 + math.random() * 0.05)
			end
			btn.TextTransparency = 0
		end)
	end)
	btn.MouseLeave:Connect(function()
		hovering = false
		btn.TextTransparency = 0
		UI.tween(btn, 0.2, { TextColor3 = normalColor })
	end)
	btn.Activated:Connect(function()
		Sound.play("UIClick", nil, { Volume = 0.7 })
		if onClick then
			onClick()
		end
	end)
	return btn
end

-- чёрная виньетка по краям экрана
function UI.vignette(parent, strength)
	strength = strength or 0
	local holder = UI.new("Frame", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = parent,
	})
	local function edge(rot, size, pos, anchor)
		local f = UI.new("Frame", {
			Size = size,
			Position = pos,
			AnchorPoint = anchor,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			BackgroundTransparency = strength,
			ZIndex = 1,
			Parent = holder,
		})
		UI.new("UIGradient", {
			Rotation = rot,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = f,
		})
		return f
	end
	edge(0, UDim2.fromScale(0.28, 1), UDim2.fromScale(0, 0), Vector2.new(0, 0))
	edge(180, UDim2.fromScale(0.28, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0))
	edge(90, UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0), Vector2.new(0, 0))
	edge(-90, UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 1), Vector2.new(0, 1))
	return holder
end

-- окно-панель с заголовком и крестиком
function UI.window(parent, titleText, size)
	local win = UI.new("Frame", {
		Name = "Window",
		Size = size or UDim2.fromOffset(760, 480),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 20,
		Parent = parent,
	}, {
		UI.corner(4),
		UI.stroke(UI.Colors.Red, 2, 0.2),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(980, 640) }),
	})
	UI.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(30, 14, 14), Color3.fromRGB(8, 6, 6)),
		Parent = win,
	})
	local title = UI.label({
		Name = "Title",
		Text = titleText,
		Font = UI.FontTitle,
		TextSize = 30,
		TextColor3 = UI.Colors.BrightRed,
		Size = UDim2.new(1, -80, 0, 44),
		Position = UDim2.fromOffset(18, 6),
		ZIndex = 21,
		Parent = win,
	})
	local line = UI.new("Frame", {
		Size = UDim2.new(1, -36, 0, 1),
		Position = UDim2.fromOffset(18, 52),
		BackgroundColor3 = UI.Colors.Red,
		BorderSizePixel = 0,
		ZIndex = 21,
		Parent = win,
	})
	local close = UI.button({
		Text = "✕",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -50, 0, 8),
		TextSize = 22,
		ZIndex = 22,
		Parent = win,
	})
	local content = UI.new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -36, 1, -72),
		Position = UDim2.fromOffset(18, 62),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = win,
	})
	local api = { frame = win, content = content, title = title, line = line, onClose = nil }
	function api.open()
		win.Visible = true
		win.Size = (size or UDim2.fromOffset(760, 480)) - UDim2.fromOffset(40, 30)
		UI.tween(win, 0.18, { Size = size or UDim2.fromOffset(760, 480) }, Enum.EasingStyle.Back)
		task.spawn(function()
			for _ = 1, 5 do
				title.TextTransparency = math.random() < 0.5 and 0.7 or 0
				task.wait(0.05)
			end
			title.TextTransparency = 0
		end)
	end
	function api.close()
		win.Visible = false
		if api.onClose then
			api.onClose()
		end
	end
	close.Activated:Connect(api.close)
	return api
end

-- всплывающее уведомление
local toastHolders = {}
function UI.toast(screenGui, text, color)
	local holder = toastHolders[screenGui]
	if not holder or not holder.Parent then
		holder = UI.new("Frame", {
			Name = "Toasts",
			Size = UDim2.new(0, 420, 1, -40),
			Position = UDim2.new(1, -20, 0, 20),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			ZIndex = 50,
			Parent = screenGui,
		}, {
			UI.new("UIListLayout", {
				Padding = UDim.new(0, 6),
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		toastHolders[screenGui] = holder
	end
	local t = UI.label({
		Text = text,
		Font = UI.FontMono,
		TextSize = 16,
		TextColor3 = color or UI.Colors.Text,
		BackgroundColor3 = Color3.fromRGB(10, 6, 6),
		BackgroundTransparency = 0.15,
		Size = UDim2.fromOffset(400, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 51,
		Parent = holder,
	}, nil)
	UI.padding(10).Parent = t
	UI.stroke(UI.Colors.Red, 1, 0.3).Parent = t
	task.delay(4, function()
		if t.Parent then
			UI.tween(t, 0.4, { TextTransparency = 1, BackgroundTransparency = 1 })
			task.wait(0.45)
			t:Destroy()
		end
	end)
	return t
end

-- глитч-заголовок: три слоя (белый + красный + голубой со сдвигом)
function UI.glitchTitle(parent, text, size, position, textSize)
	local holder = UI.new("Frame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = parent,
	})
	local function layer(color, z, tr)
		return UI.label({
			Text = text,
			Font = UI.FontTitle,
			TextSize = textSize,
			TextColor3 = color,
			TextTransparency = tr,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false,
			ZIndex = z,
			Parent = holder,
		})
	end
	local cyan = layer(Color3.fromRGB(60, 220, 255), 5, 0.55)
	local red = layer(Color3.fromRGB(255, 20, 20), 6, 0.25)
	local main = layer(Color3.fromRGB(235, 225, 215), 7, 0)
	local alive = true
	task.spawn(function()
		while alive and holder.Parent do
			local glitch = math.random() < 0.12
			if glitch then
				for _ = 1, math.random(3, 8) do
					red.Position = UDim2.fromOffset(math.random(-9, 9), math.random(-3, 3))
					cyan.Position = UDim2.fromOffset(math.random(-9, 9), math.random(-3, 3))
					main.Position = UDim2.fromOffset(math.random(-3, 3), 0)
					main.TextTransparency = math.random() < 0.3 and 0.8 or 0
					task.wait(0.03)
				end
			end
			red.Position = UDim2.fromOffset(2, 1)
			cyan.Position = UDim2.fromOffset(-2, 0)
			main.Position = UDim2.fromOffset(0, 0)
			main.TextTransparency = 0
			task.wait(0.08 + math.random() * 0.25)
		end
	end)
	return holder, function()
		alive = false
	end
end

return UI
