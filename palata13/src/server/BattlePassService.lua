-- Серверная логика батлпасса: опыт и выдача наград
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Parent.Remotes)
local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)
local Config = require(ReplicatedStorage.Shared.Config)
local BattlePass = require(ReplicatedStorage.Shared.BattlePass)

local BPService = {}

function BPService.addXP(player, amount)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	local before = BattlePass.tierFromXP(data.xp)
	data.xp += math.floor(amount)
	local after = BattlePass.tierFromXP(data.xp)
	if after > before then
		Remotes.notify(player, "БАТЛПАСС: уровень " .. after .. "! Забери награду в лобби.", Color3.fromRGB(235, 40, 40))
	end
end

local function grantReward(player, data, reward)
	if reward.type == "coins" then
		data.coins += reward.amount
	elseif reward.type == "revive" then
		data.revives += reward.amount
	elseif reward.type == "flashlight" then
		data.flashlights[reward.id] = true
	elseif reward.type == "title" then
		data.titles[reward.id] = true
	end
end

function BPService.claim(player, tier, track)
	local data = DataService.get(player)
	if not data then
		return false, "Данные ещё загружаются"
	end
	tier = tonumber(tier)
	if not tier or tier < 1 or tier > BattlePass.MaxTier or tier ~= math.floor(tier) then
		return false, "Неверный уровень"
	end
	if track ~= "free" and track ~= "premium" then
		return false, "?"
	end
	if BattlePass.tierFromXP(data.xp) < tier then
		return false, "Уровень ещё не открыт"
	end
	if track == "premium" and not ShopService.hasPass(player, "PremiumPass") then
		return false, "Нужен ПРЕМИУМ БАТЛПАСС"
	end
	local k = tostring(tier)
	if data.bpClaimed[track][k] then
		return false, "Уже получено"
	end
	local reward = BattlePass.Tiers[tier][track]
	if not reward then
		return false, "Нет награды"
	end
	data.bpClaimed[track][k] = true
	grantReward(player, data, reward)
	ShopService.applyCosmetics(player)
	DataService.push(player)
	return true, "Получено: " .. BattlePass.describe(reward)
end

function BPService.start()
	Remotes.ClaimReward.OnServerInvoke = function(player, tier, track)
		return BPService.claim(player, tier, track)
	end
end

local _ = Config
return BPService
