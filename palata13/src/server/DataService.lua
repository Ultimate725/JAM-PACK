--[[
	Сохранение прогресса (DataStore). Общий для лобби и игрового плейса
	(оба плейса должны быть в одном Experience).
	Защита от гонки при телепорте: в TeleportData передаём savedAt, и
	принимающий сервер ждёт, пока в DataStore появится версия не старше.
]]
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Remotes = require(script.Parent.Remotes)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local BattlePass = require(Shared.BattlePass)

local DataService = {}
DataService.passChecker = nil -- function(player) -> table of pass flags (ставит ShopService)

local STORE_NAME = "Palata13_PlayerData_v1"
local store = nil
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)
if not storeOk then
	store = nil
end

local profiles = {}
local loadedEvent = Instance.new("BindableEvent")
DataService.Loaded = loadedEvent.Event

local function defaults()
	return {
		version = 1,
		coins = 100,
		xp = 0,
		bpClaimed = { free = {}, premium = {} },
		flashlights = { Standard = true },
		flashlight = "Standard",
		titles = { Newbie = true },
		title = "Newbie",
		revives = 0,
		stats = { escapes = 0, deaths = 0, games = 0 },
		receipts = {},
		receiptOrder = {},
		savedAt = 0,
		settings = { sensitivity = 1, music = 0.6 },
	}
end

local function merge(data, def)
	for k, v in pairs(def) do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			merge(data[k], v)
		end
	end
	return data
end

local function key(player)
	return "u_" .. player.UserId
end

local function setupLeaderstats(player, data)
	local ls = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = ls:FindFirstChild("Монеты") or Instance.new("IntValue")
	coins.Name = "Монеты"
	coins.Value = data.coins
	coins.Parent = ls
	local tier = ls:FindFirstChild("Уровень") or Instance.new("IntValue")
	tier.Name = "Уровень"
	tier.Value = BattlePass.tierFromXP(data.xp)
	tier.Parent = ls
	ls.Parent = player
end

local function snapshot(player, data)
	-- то, что уходит клиенту
	local passes = DataService.passChecker and DataService.passChecker(player) or {}
	return {
		coins = data.coins,
		xp = data.xp,
		tier = BattlePass.tierFromXP(data.xp),
		bpClaimed = data.bpClaimed,
		flashlights = data.flashlights,
		flashlight = data.flashlight,
		titles = data.titles,
		title = data.title,
		revives = data.revives,
		stats = data.stats,
		passes = passes,
		settings = data.settings,
	}
end

function DataService.push(player)
	local data = profiles[player]
	if not data then
		return
	end
	setupLeaderstats(player, data)
	Remotes.DataUpdated:FireClient(player, snapshot(player, data))
end

function DataService.get(player)
	return profiles[player]
end

function DataService.waitFor(player, timeout)
	local t0 = os.clock()
	while not profiles[player] and player.Parent and os.clock() - t0 < (timeout or 30) do
		task.wait(0.2)
	end
	return profiles[player]
end

function DataService.update(player, fn)
	local data = profiles[player]
	if not data then
		return false
	end
	fn(data)
	DataService.push(player)
	return true
end

function DataService.saveAsync(player)
	local data = profiles[player]
	if not data then
		return false, 0
	end
	data.savedAt = os.time() + os.clock() % 1
	if not store then
		return true, data.savedAt
	end
	local ok, err
	for attempt = 1, 3 do
		ok, err = pcall(function()
			store:SetAsync(key(player), data, { player.UserId })
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	if not ok then
		warn("[Палата13] Не удалось сохранить", player.Name, err)
	end
	return ok, data.savedAt
end

local function loadPlayer(player)
	local expectedSavedAt = 0
	pcall(function()
		local join = player:GetJoinData()
		local td = join and join.TeleportData
		if type(td) == "table" then
			if type(td.savedAt) == "number" then
				expectedSavedAt = td.savedAt
			elseif type(td.savedAt) == "table" then
				expectedSavedAt = tonumber(td.savedAt[tostring(player.UserId)]) or 0
			end
		end
	end)

	local data = nil
	if store then
		for attempt = 1, 8 do
			local ok, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if ok then
				if type(result) == "table" and (result.savedAt or 0) + 0.001 < expectedSavedAt and attempt < 8 then
					-- предыдущий сервер ещё не дописал данные — подождём
					task.wait(1.5)
				else
					data = result
					break
				end
			else
				warn("[Палата13] Ошибка загрузки", result)
				if RunService:IsStudio() then
					warn("[Палата13] В Studio включи: Game Settings → Security → Enable Studio Access to API Services")
					break
				end
				task.wait(attempt)
			end
		end
	end
	if not player.Parent then
		return
	end
	if type(data) ~= "table" then
		data = defaults()
	else
		data = merge(data, defaults())
	end
	profiles[player] = data
	setupLeaderstats(player, data)
	loadedEvent:Fire(player, data)
	DataService.push(player)
end

-- квитанции покупок (защита от двойного начисления)
function DataService.hasReceipt(data, purchaseId)
	return data.receipts[purchaseId] == true
end

function DataService.addReceipt(data, purchaseId)
	data.receipts[purchaseId] = true
	table.insert(data.receiptOrder, purchaseId)
	while #data.receiptOrder > 50 do
		local old = table.remove(data.receiptOrder, 1)
		data.receipts[old] = nil
	end
end

function DataService.start()
	Remotes.GetData.OnServerInvoke = function(player)
		local data = DataService.waitFor(player, 20)
		if not data then
			return nil
		end
		return snapshot(player, data)
	end

	Players.PlayerAdded:Connect(loadPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(loadPlayer, p)
	end

	Players.PlayerRemoving:Connect(function(player)
		if profiles[player] then
			if not player:GetAttribute("AlreadySaved") then
				DataService.saveAsync(player)
			end
			profiles[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(120)
			for _, p in ipairs(Players:GetPlayers()) do
				task.spawn(DataService.saveAsync, p)
			end
		end
	end)

	game:BindToClose(function()
		local threads = 0
		for _, p in ipairs(Players:GetPlayers()) do
			threads += 1
			task.spawn(function()
				DataService.saveAsync(p)
				threads -= 1
			end)
		end
		local t0 = os.clock()
		while threads > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
end

local _ = HttpService
return DataService
