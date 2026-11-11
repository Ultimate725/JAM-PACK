--[[
	Магазин: Game Pass'ы, Developer Products (за Робуксы), покупка фонариков за монеты,
	экипировка фонариков и титулов.
	ProcessReceipt слушается в обоих плейсах (в раунде можно купить возрождение).
]]
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Parent.Remotes)
local DataService = require(script.Parent.DataService)
local Config = require(ReplicatedStorage.Shared.Config)
local BattlePass = require(ReplicatedStorage.Shared.BattlePass)

local ShopService = {}
ShopService.onRevivePurchased = nil -- function(player) -> true, если возродили в раунде
ShopService.isLobby = false

local passCache = {} -- [player][key] = bool

function ShopService.hasPass(player, key)
	local id = Config.GamePasses[key]
	if not id or id == 0 then
		return false
	end
	passCache[player] = passCache[player] or {}
	local cached = passCache[player][key]
	if cached ~= nil then
		return cached
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	local value = ok and owns == true
	if ok then
		passCache[player][key] = value
	end
	return value
end

local function passFlags(player)
	local flags = {}
	for key in pairs(Config.GamePasses) do
		flags[key] = ShopService.hasPass(player, key)
	end
	return flags
end
DataService.passChecker = passFlags

-- цвет фонарика + титул в атрибутах и над головой
function ShopService.applyCosmetics(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local fl = Config.getFlashlight(data.flashlight)
	player:SetAttribute("FlashColor", fl.color)
	player:SetAttribute("FlashlightId", fl.id)
	local titleId = data.title
	if ShopService.hasPass(player, "VIP") then
		data.titles.VIP = true
	end
	local t = Config.getTitle(titleId) or Config.getTitle("Newbie")
	player:SetAttribute("Title", t.name)
	player:SetAttribute("BigBattery", ShopService.hasPass(player, "BigBattery"))
	player:SetAttribute("VIP", ShopService.hasPass(player, "VIP"))

	local char = player.Character
	if ShopService.isLobby and Config.ShowTitlesAboveHead and char then
		local head = char:FindFirstChild("Head")
		if head then
			local bb = head:FindFirstChild("TitleTag")
			if not bb then
				bb = Instance.new("BillboardGui")
				bb.Name = "TitleTag"
				bb.Size = UDim2.fromOffset(220, 26)
				bb.StudsOffset = Vector3.new(0, 2.6, 0)
				bb.MaxDistance = 60
				bb.AlwaysOnTop = false
				local l = Instance.new("TextLabel")
				l.Name = "L"
				l.Size = UDim2.fromScale(1, 1)
				l.BackgroundTransparency = 1
				l.Font = Enum.Font.SourceSansBold
				l.TextSize = 18
				l.TextStrokeTransparency = 0.4
				l.Parent = bb
				bb.Parent = head
			end
			bb.L.Text = "« " .. t.name .. " »"
			bb.L.TextColor3 = t.color
		end
	end
end

local function grantProduct(player, key)
	local reward = Config.ProductRewards[key]
	if not reward then
		return false
	end
	local data = DataService.get(player)
	if not data then
		return false
	end
	if reward.coins then
		data.coins += reward.coins
		Remotes.notify(player, "+" .. reward.coins .. " монет. Спасибо за покупку!", Color3.fromRGB(235, 185, 70))
	end
	if reward.tiers then
		local tier = BattlePass.tierFromXP(data.xp)
		if tier < BattlePass.MaxTier then
			data.xp = (tier + 1) * BattlePass.XPPerTier
		else
			data.coins += 300 -- батлпасс уже закрыт — компенсация
		end
		Remotes.notify(player, "Уровень батлпасса повышен!", Color3.fromRGB(235, 40, 40))
	end
	if reward.revive then
		local used = false
		if ShopService.onRevivePurchased then
			used = ShopService.onRevivePurchased(player) == true
		end
		if not used then
			data.revives += reward.revive
			Remotes.notify(player, "+1 жетон возрождения", Color3.fromRGB(110, 200, 110))
		end
	end
	return true
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.waitFor(player, 15)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if DataService.hasReceipt(data, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = Config.productKeyById(info.ProductId)
	if not key then
		warn("[Палата13] Неизвестный продукт", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not grantProduct(player, key) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.addReceipt(data, info.PurchaseId)
	local ok = DataService.saveAsync(player)
	DataService.push(player)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function handleShopRequest(player, action, arg)
	local data = DataService.get(player)
	if not data then
		return false, "Данные ещё загружаются"
	end
	if action == "buyFlashlight" then
		local fl = nil
		for _, f in ipairs(Config.Flashlights) do
			if f.id == arg then
				fl = f
			end
		end
		if not fl then
			return false, "Нет такого фонарика"
		end
		if fl.source == "bp" then
			return false, "Только из батлпасса"
		end
		if data.flashlights[fl.id] then
			return false, "Уже куплено"
		end
		if data.coins < fl.price then
			return false, "Не хватает монет"
		end
		data.coins -= fl.price
		data.flashlights[fl.id] = true
		data.flashlight = fl.id
		ShopService.applyCosmetics(player)
		DataService.push(player)
		return true, "Куплено: " .. fl.name
	elseif action == "equipFlashlight" then
		if not data.flashlights[arg] then
			return false, "Не куплено"
		end
		data.flashlight = arg
		ShopService.applyCosmetics(player)
		DataService.push(player)
		return true, "Экипировано"
	elseif action == "equipTitle" then
		if arg == "VIP" and ShopService.hasPass(player, "VIP") then
			data.titles.VIP = true
		end
		if not data.titles[arg] then
			return false, "Титул не получен"
		end
		data.title = arg
		ShopService.applyCosmetics(player)
		DataService.push(player)
		return true, "Титул установлен"
	end
	return false, "?"
end

function ShopService.start(isLobby)
	ShopService.isLobby = isLobby == true
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = Config.passKeyById(passId)
		if key then
			passCache[player] = passCache[player] or {}
			passCache[player][key] = true
			local data = DataService.get(player)
			if key == "VIP" and data then
				data.titles.VIP = true
			end
			Remotes.notify(player, "Пропуск активирован. Оно теперь знает твоё имя.", Color3.fromRGB(235, 185, 70))
			ShopService.applyCosmetics(player)
			DataService.push(player)
		end
	end)

	Remotes.ShopRequest.OnServerInvoke = function(player, action, arg)
		if type(action) ~= "string" then
			return false, "?"
		end
		return handleShopRequest(player, action, arg)
	end

	DataService.Loaded:Connect(function(player)
		ShopService.applyCosmetics(player)
	end)

	local function onPlayer(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			ShopService.applyCosmetics(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		passCache[p] = nil
	end)
end

return ShopService
