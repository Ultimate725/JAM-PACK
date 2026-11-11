-- Static sanity harness for the shared config (runs in the standalone `luau` CLI, no Roblox).
Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end, new = function(r, g, b) return { r = r, g = g, b = b } end }
script = { Parent = { Config = "../src/shared/Config" } }
local Config = require("../src/shared/Config")
local BP = require("../src/shared/BattlePass")

local errors = 0
local function check(cond, msg)
	if not cond then
		errors += 1
		print("FAIL: " .. msg)
	end
end

check(#Config.Maps == 3, "3 maps")
for _, m in ipairs(Config.Maps) do
	for _, k in ipairs({ "id", "name", "subtitle", "icon", "story", "goal", "generators", "ambience", "lighting", "color" }) do
		check(m[k] ~= nil, "map " .. m.id .. " missing " .. k)
	end
	check(Config.Sounds[m.ambience] ~= nil, "map ambience key exists: " .. tostring(m.ambience))
end
check(#Config.Difficulties == 4, "4 difficulties")
local ids = {}
for _, d in ipairs(Config.Difficulties) do
	ids[d.id] = true
	for _, k in ipairs({ "crouch", "walk", "sprint", "flashlight", "interact" }) do
		check(type(d.hear[k]) == "number", d.id .. " hear." .. k)
	end
	for _, k in ipairs({ "patrol", "investigate", "chase" }) do
		check(type(d.speed[k]) == "number", d.id .. " speed." .. k)
	end
	for _, k in ipairs({ "blind", "sight", "flashlightSight", "fov", "loseTime", "wakeDelay", "generators", "timeLimit", "sonar", "sense", "xpMult", "coinMult", "desc", "color", "icon" }) do
		check(d[k] ~= nil, d.id .. " missing " .. k)
	end
	if d.blind then
		check(d.hear.crouch > 0 and d.hear.walk > 0, d.id .. ": blind must hear crouch/walk")
	else
		check(d.sight > 0, d.id .. ": sighted must have sight range")
	end
	check(d.generators >= 1 and d.generators <= 4, d.id .. " generators 1..4")
end
check(ids.Easy and ids.Medium and ids.Hard and ids.Nightmare, "difficulty ids")
check(Config.getDifficulty("nope").id == "Medium", "default difficulty is Medium")
check(Config.getMap("nope").id == "Hospital", "default map is Hospital")
for _, p in ipairs(Config.Perks) do
	check(p.price > 0 and p.name and p.desc and p.icon, "perk " .. p.id)
	check(p.consumable or (p.stat and p.value), "perk effect " .. p.id)
end
for tier, row in ipairs(BP.Tiers) do
	for _, track in ipairs({ "free", "premium" }) do
		local r = row[track]
		check(r ~= nil, "tier " .. tier .. " " .. track)
		if r and r.type == "flashlight" then
			check(Config.getFlashlight(r.id).id == r.id, "bp flashlight exists " .. r.id)
		elseif r and r.type == "title" then
			check(Config.getTitle(r.id) ~= nil, "bp title exists " .. r.id)
		end
	end
end
check(Config.Player.CrouchSpeed < Config.Player.WalkSpeed, "crouch slower than walk")
print(errors == 0 and "config OK" or ("config errors: " .. errors))
