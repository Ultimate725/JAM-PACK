-- Paste this over the Config.Sounds = { ... } block in ReplicatedStorage > Shared > Config
-- in BOTH places (Palata13_Lobby and Palata13_Game). Replace each 0 with the asset ID you got
-- after uploading the matching file from the Sounds folder (e.g. Sounds/MonsterScream.ogg).
-- If you used upload_sounds.py, it already wrote Config_Sounds_filled.lua for you.
Config.Sounds = {
	FlashlightOn = 0, -- Sounds/FlashlightOn.ogg
	FlashlightOff = 0, -- Sounds/FlashlightOff.ogg
	MonsterStep = 0, -- Sounds/MonsterStep.ogg
	MonsterBreath = 0, -- Sounds/MonsterBreath.ogg (loop)
	MonsterScream = 0, -- Sounds/MonsterScream.ogg
	MonsterSniff = 0, -- Sounds/MonsterSniff.ogg
	Sonar = 0, -- Sounds/Sonar.ogg
	ChaseSting = 0, -- Sounds/ChaseSting.ogg
	Ambience = 0, -- Sounds/Ambience.ogg (loop, hospital)
	AmbienceMorgue = 0, -- Sounds/AmbienceMorgue.ogg (loop)
	AmbienceForest = 0, -- Sounds/AmbienceForest.ogg (loop, sanatorium)
	MenuMusic = 0, -- Sounds/MenuMusic.ogg (loop)
	Heartbeat = 0, -- Sounds/Heartbeat.ogg (loop)
	Static = 0, -- Sounds/Static.ogg
	UIHover = 0, -- Sounds/UIHover.ogg
	UIClick = 0, -- Sounds/UIClick.ogg
	Pickup = 0, -- Sounds/Pickup.ogg
	FuseInsert = 0, -- Sounds/FuseInsert.ogg
	GeneratorOn = 0, -- Sounds/GeneratorOn.ogg
	GeneratorCrank = 0, -- Sounds/GeneratorCrank.ogg
	GateOpen = 0, -- Sounds/GateOpen.ogg
	Purchase = 0, -- Sounds/Purchase.ogg
	Teleport = 0, -- Sounds/Teleport.ogg
	Whisper = 0, -- Sounds/Whisper.ogg
	LightBuzz = 0, -- Sounds/LightBuzz.ogg (loop)
	MetalBang = 0, -- Sounds/MetalBang.ogg
	Breathing = 0, -- Sounds/Breathing.ogg (loop)
	Cloth = 0, -- Sounds/Cloth.ogg
	Drip = 0, -- Sounds/Drip.ogg
	Wind = 0, -- Sounds/Wind.ogg (loop)
	Crow = 0, -- Sounds/Crow.ogg
	Bell = 0, -- Sounds/Bell.ogg
}

-- Game passes (Creator Hub > your game > Monetization > Passes). Icons: Store/GamePass_*.png
Config.GamePasses = {
	PremiumPass = 0, -- Store/GamePass_PremiumPass_512.png  (suggested 199 R$)
	VIP = 0, -- Store/GamePass_VIP_512.png          (suggested 249 R$)
	BigBattery = 0, -- Store/GamePass_BigBattery_512.png   (suggested 99 R$)
}

-- Developer products (Monetization > Developer Products). Icons: Store/Product_*.png
Config.Products = {
	Coins100 = 0, -- Store/Product_Coins100_512.png   (suggested 25 R$)
	Coins500 = 0, -- Store/Product_Coins500_512.png   (suggested 99 R$)
	Coins1500 = 0, -- Store/Product_Coins1500_512.png  (suggested 249 R$)
	SkipTier = 0, -- Store/Product_SkipTier_512.png   (suggested 49 R$)
	Revive = 0, -- Store/Product_Revive_512.png     (suggested 25 R$)
}

-- Place IDs (Creator Hub > your game > Places). The Lobby must be the start place.
Config.LobbyPlaceId = 0
Config.GamePlaceId = 0
