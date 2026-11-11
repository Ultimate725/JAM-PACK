# ПАЛАТА 13 — v2.0

Roblox horror game (two places: **Lobby** and **Game**). This folder contains everything needed to
rebuild both `.rbxlx` place files from source:

```
palata13/
  base/        original place files (used as the geometry base)
  src/         Lua sources (shared / server / client) — edit these, not the rbxlx
  gen/         procedural generators: monster, lobby kiosks & menu scene, hospital upgrades, Morgue, Sanatorium
  buildkit/    rbxlx XML writer, CFrame math, scene helpers, PNG verification renderer
  tools/       preview_map.py — renders + validates a map module
  build.py     builds dist/Palata13_Lobby.rbxlx and dist/Palata13_Game.rbxlx
  dist/        built place files (open these in Roblox Studio)
```

Build: `python3 build.py --check` (needs Python 3.10+ and Pillow only for previews).

## What is in v2.0

* **3 maps with their own stories** (chosen at the gate console in the lobby): ПАЛАТА 13 (the hospital),
  МОРГ (underground morgue, flooded tunnel, crematorium, freight elevator exit) and САНАТОРИЙ «СОСНЫ»
  (foggy forest sanatorium: main building, chapel with bell tower, boiler house, bathhouse, garage, iron gate exit).
  All maps live in `ServerStorage.Maps.<id>` of the Game place and are cloned into `workspace.Map` at round start.
* **4 difficulties** (`Config.Difficulties`): ЛЕГКО (blind monster, keen hearing, slow), СРЕДНЕ (sees + hears sprint),
  СЛОЖНО (sees far, hears steps and flashlight clicks), КОШМАР (blind but hears everything, sonar screams every
  30 s that reveal anyone moving, very fast). Blind difficulties spawn the `Blind` monster variant (sewn eyes, bandages).
* **Gate console** (`Console1..3` next to each gate): map, difficulty and party size (1–4) per gate; sent through
  `TeleportData { map, difficulty, maxPlayers }`.
* **Generators**: every map has 4 generators (`Map.Generators`); the difficulty decides how many are needed.
  Each one needs a fuse (pickup) and then a noisy repair (hold E, progress persists). When enough run:
  the lights turn on, the exit gate(s) slide open, the monster goes into rage.
* **Crouch** (C / LeftCtrl / gamepad B; toggle or hold in settings): slower, lower camera, much quieter.
  The HUD shows a noise meter; the monster hears crouch < walk < sprint < flashlight click < interactions.
* **Volume**: master / music / effects sliders (lobby settings and in-game `M`), persisted in the profile via
  `SoundService.Master{Music,SFX}` SoundGroups; mouse sensitivity and crouch mode too.
* **Lobby shops**: касса (Robux), лавка фонарей (flashlight skins), аптека (coin perks: quiet slippers, second wind,
  wrench, charm, adrenaline, spare batteries, steel nerves, revive tokens), регистратура (titles incl. new
  map/nightmare titles), план больницы (map stories). Shop window tabs: РОБУКСЫ / ФОНАРИКИ / ПЕРКИ / ТИТУЛЫ.
* **Main menu**: "security-camera recording" with REC timecode, VHS lines, dust in the flashlight beam, blackouts that
  bring the Patient closer each time (wheelchair rolls, a door slams, a lamp swings), ending with a face-to-face
  scream and "СИГНАЛ ПОТЕРЯН". Tabs: ИГРАТЬ / КАРТЫ / МАГАЗИН / БАТЛПАСС / ПРОФИЛЬ / НАСТРОЙКИ.
* **Monster** rebuilt procedurally (`gen/monster.py`, ~340 parts): halo brace screwed into the skull, sewn/glowing
  eyes, split jaw with two rows of teeth and a hanging tongue (dripping), exposed ribs and spine, sutured belly wound,
  restraint straps, IV line, chain with hook, bone saw, claws, long greasy hair, ink-smoke aura, dust at the feet.
  Animator adds listening head-tilts for the blind variant, sonar pose, eye glow by state, rage light.

## Setting up in Roblox Studio

1. Open `dist/Palata13_Lobby.rbxlx` and `dist/Palata13_Game.rbxlx`, publish both places into ONE experience.
2. In **both** places set `ReplicatedStorage.Shared.Config`: `LobbyPlaceId`, `GamePlaceId`, sound asset ids,
   game-pass / product ids. (Sounds are optional: id 0 = silent.)
3. Enable *Game Settings → Security → Enable Studio Access to API Services* for DataStores.
4. In Studio you can test a map without the lobby: set the attributes `TestMap` (Hospital / Morgue / Sanatorium)
   and `TestDifficulty` (Easy / Medium / Hard / Nightmare) on `Workspace` of the Game place and press Play.

Note: the "AAA detail" is procedural part geometry (no uploaded meshes/textures), so detail comes from part count,
materials and lighting; swap in MeshParts/textures later if you want photoreal assets.
