ПАЛАТА 13 (WARD 13) - v2.0 - EVERYTHING YOU NEED TO ADD
==========================================================

WHAT IS IN THIS ZIP
-------------------
  Palata13_Lobby.rbxlx        Lobby place (start place): main menu, shops, gates + gate consoles
  Palata13_Game.rbxlx         Game place: 3 maps (Hospital, Morgue, Sanatorium), monster, rounds
  Sounds/                     32 original sound files (.ogg) - one per entry in Config.Sounds
  Store/                      Game icon, game thumbnail, 3 game-pass icons, 5 developer-product icons
  Config_IDs_template.lua     The Config blocks to fill in (sounds, passes, products, place IDs)
  upload_sounds.py            OPTIONAL: uploads all 32 sounds automatically and fills the IDs for you
  readme.txt                  This file

All sounds and images were made from scratch for this game (procedurally generated),
so you own them and can upload them without copyright problems.


STEP 1 - PUBLISH THE TWO PLACES (about 5 minutes)
------------------------------------------------
 1. Open Roblox Studio > File > Open from File > Palata13_Lobby.rbxlx
 2. File > Publish to Roblox As... > create a NEW experience (this becomes the start place).
 3. Creator Hub (create.roblox.com) > your experience > Places > Add Place (a second place).
 4. Open Palata13_Game.rbxlx in Studio > File > Publish to Roblox As... > choose your experience
    > choose the second place you just created.
 5. Note both Place IDs (Creator Hub > Places, the number in each place's URL).
 6. In BOTH places: Game Settings > Security > turn ON "Enable Studio Access to API Services"
    (needed for saving coins/battle pass/progress with DataStores).


STEP 2 - UPLOAD THE SOUNDS (choose A or B)
------------------------------------------
Upload with the SAME account (or group) that owns the experience - Roblox audio is private
and only plays in experiences owned by the uploader.

 A) Manual (no setup):
    Studio > View > Asset Manager > "Bulk Import" (the up-arrow icon) > select all 32 files
    in the Sounds folder. After it finishes, right-click each sound > Copy Asset ID, and paste
    the number into Config_IDs_template.lua next to the matching name.
    (Or upload one by one at create.roblox.com > Creations > Audio.)
    Roblox has a monthly free audio upload limit; ID-verified accounts get a much higher limit.

 B) Automatic (Python 3.8+ installed):
    1. create.roblox.com/dashboard/credentials > Create API Key
       Access Permissions: add "Assets" with Read + Write. IP: add your IP (or 0.0.0.0/0).
    2. Open a terminal in this folder and run:
         Windows:      set ROBLOX_API_KEY=your_key_here
                       python upload_sounds.py --user-id YOUR_USER_ID
         macOS/Linux:  ROBLOX_API_KEY=your_key_here python3 upload_sounds.py --user-id YOUR_USER_ID
       (group-owned game: use --group-id YOUR_GROUP_ID instead of --user-id)
    3. It writes Config_Sounds_filled.lua with all 32 IDs. If it stops (rate limit, network),
       just run it again - it skips sounds already uploaded (saved in sound_ids.txt).

New audio is moderated; a sound may stay silent for a few minutes until it is approved.


STEP 3 - CREATE THE GAME PASSES AND DEVELOPER PRODUCTS (optional, for Robux income)
----------------------------------------------------------------------------------
Creator Hub > your experience > Monetization.

 Game passes (Passes > Create a Pass), use the icon from the Store folder:
   PremiumPass   GamePass_PremiumPass_512.png   premium battle-pass track        ~199 R$
   VIP           GamePass_VIP_512.png           x2 coins + VIP title             ~249 R$
   BigBattery    GamePass_BigBattery_512.png    flashlight drains 2x slower      ~99 R$

 Developer products (Developer Products > Create):
   Coins100      Product_Coins100_512.png       +100 coins                       ~25 R$
   Coins500      Product_Coins500_512.png       +500 coins                       ~99 R$
   Coins1500     Product_Coins1500_512.png      +1500 coins                      ~249 R$
   SkipTier      Product_SkipTier_512.png       +1 battle-pass tier              ~49 R$
   Revive        Product_Revive_512.png         revive token / revive in round   ~25 R$

 Prices are suggestions; the shop reads the real price from Roblox automatically.
 Copy every pass/product ID into Config_IDs_template.lua. Anything left at 0 just shows
 "not configured" in the shop - the game still works.

 Game icon + thumbnail: Creator Hub > your experience > Configure > Places/Experience
   > upload Store/GameIcon_512.png as the icon and Store/Thumbnail_1920x1080.png as a thumbnail.


STEP 4 - PUT THE IDs INTO THE GAME (both places!)
------------------------------------------------
 In Studio, in BOTH Palata13_Lobby and Palata13_Game:
   Explorer > ReplicatedStorage > Shared > Config (ModuleScript)
   - Config.LobbyPlaceId = <lobby place id>
   - Config.GamePlaceId  = <game place id>
   - replace the Config.Sounds / Config.GamePasses / Config.Products blocks with the ones
     you filled in (Config_IDs_template.lua or Config_Sounds_filled.lua).
 Publish both places again (File > Publish to Roblox).


STEP 5 - TEST
-------------
 * Quick test of one map in Studio without the lobby: open the Game place, select Workspace,
   add attributes:  TestMap = Hospital | Morgue | Sanatorium
                    TestDifficulty = Easy | Medium | Hard | Nightmare
   then press Play. (Teleports between places only work in the real Roblox client, not in Studio.)
 * Full test: play the published experience from the Roblox website. In the lobby press PLAY,
   walk to a gate console (E) to choose map / difficulty / number of players, then stand in the
   glowing circle under the gate.


CONTROLS
--------
 F flashlight . SHIFT sprint . C or Left Ctrl crouch (quiet) . E interact / hide / repair
 M settings in a round (volume sliders, sensitivity, crouch toggle/hold)


HOW A ROUND WORKS
-----------------
 Find fuses -> put one in a generator -> hold E to repair it (noisy, progress is kept).
 Easy needs 2 generators, Medium/Hard 3, Nightmare 4. When enough run: the lights come on,
 the exit gate opens and the monster becomes enraged. Reach the exit zone to escape.
 Easy/Nightmare: the monster is BLIND but hears you (crouch!). Medium/Hard: it also sees you.
 Nightmare: every 30 s it screams - if you are moving at that moment, it knows where you are.


SOUND LIST (file -> what it is / where it plays)
------------------------------------------------
 FlashlightOn / FlashlightOff   flashlight click (players hear each other)
 MonsterStep                    heavy footstep of the monster (shakes the camera nearby)
 MonsterBreath        (loop)    wet breathing attached to the monster's head
 MonsterScream                  scream on spotting you and in the jumpscare
 MonsterSniff                   blind monster sniffing / listening
 Sonar                          Nightmare echo-scream
 ChaseSting                     music stab when a chase starts
 Ambience             (loop)    hospital background drone
 AmbienceMorgue       (loop)    morgue: fridge hum, drips, knocking from the drawers
 AmbienceForest       (loop)    sanatorium: wind in the pines, crows, distant bell
 MenuMusic            (loop)    main menu music (drone + broken music box)
 Heartbeat            (loop)    gets faster when the monster is close
 Static                         radio static (scares, death screen)
 UIHover / UIClick              menu buttons
 Pickup                         fuse / battery pickup
 FuseInsert                     fuse into a generator
 GeneratorOn                    generator starts (also when all are fixed)
 GeneratorCrank                 repairing a generator
 GateOpen                       exit gate / elevator grille opening
 Purchase                       shop purchase, escape
 Teleport                       teleport between lobby and game
 Whisper                        random whispers behind you
 LightBuzz            (loop)    flickering lamps
 MetalBang                      lockers, distant bangs
 Breathing            (loop)    your own breathing while crouched
 Cloth                          crouch / stand up rustle
 Drip                           water drips (morgue + hospital)
 Wind                 (loop)    wind on the sanatorium map
 Crow                           crows on the sanatorium map
 Bell                           chapel bell with no ringer (sanatorium)


KNOWN LIMITS / NOTES
--------------------
 * Not yet play-tested inside Roblox Studio - expect to tune AI speeds, lighting and some
   positions after the first test. All values are in ReplicatedStorage > Shared > Config.
 * Detail comes from Roblox parts, materials and lights (no uploaded meshes/textures).
 * The source code and the generators that rebuild these files are in the GitHub PR
   (folder palata13/: build.py, src/, gen/, tools/make_sounds.py, tools/make_store_art.py).
