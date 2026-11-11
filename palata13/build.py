#!/usr/bin/env python3
"""Build the two Roblox place files from the base places + Lua sources + procedural content.

    python3 build.py            -> palata13/dist/Palata13_Lobby.rbxlx, palata13/dist/Palata13_Game.rbxlx
    python3 build.py --check    -> also re-parse the output and print structure checks

Lobby place : base lobby + kiosks/consoles/menu scene + new MenuMonster + scripts
Game place  : base hospital moved to ServerStorage.Maps.Hospital (+4 generators), plus the generated
              Morgue and Sanatorium maps, ServerStorage.Monsters (Patient / Blind), SoundGroups, scripts
"""
import os
import sys
import time
import importlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from buildkit import rbxml as X  # noqa: E402
from buildkit.kit import Scene  # noqa: E402
from gen import hospital_extra, lobby_extra  # noqa: E402
from gen.monster import build_monster  # noqa: E402

BASE = os.path.join(HERE, "base")
SRC = os.path.join(HERE, "src")
DIST = os.path.join(HERE, "dist")

# script name -> (source file, class)
SHARED = ["BattlePass", "ClientData", "Config", "FlashlightClient", "Footsteps", "MonsterAnimator", "RepairAnim", "Sound", "UI"]
CORE = ["BattlePassService", "DataService", "FlashlightService", "Remotes", "ShopService"]


def read_src(rel):
    with open(os.path.join(SRC, rel), encoding="utf-8") as f:
        return f.read()


def set_source(elem, source):
    X.set_prop(elem, "ProtectedString", "Source", source)


def put_script(doc, parent, cls, name, source):
    old = X.child(parent, name)
    if old is not None and old.get("class") == cls:
        set_source(old, source)
        return old
    if old is not None:
        parent.remove(old)
    e = X.item(doc, cls, name, parent=parent)
    set_source(e, source)
    return e


def install_scripts(root, doc, place):
    shared = X.path(root, "ReplicatedStorage/Shared")
    for name in SHARED:
        put_script(doc, shared, "ModuleScript", name, read_src("shared/%s.lua" % name))
    core = X.path(root, "ServerScriptService/Core")
    for name in CORE:
        put_script(doc, core, "ModuleScript", name, read_src("server/%s.lua" % name))
    sss = X.path(root, "ServerScriptService")
    sps = X.path(root, "StarterPlayer/StarterPlayerScripts")
    put_script(doc, sps, "LocalScript", "Signs", read_src("client/Signs.client.lua"))
    # пустой RbxCharacterSounds отключает стандартные шаги Roblox — свои шаги с эхом в Shared/Footsteps
    put_script(doc, sps, "LocalScript", "RbxCharacterSounds", "-- отключено: шаги и эхо — ReplicatedStorage.Shared.Footsteps\n")
    if place == "lobby":
        put_script(doc, sss, "Script", "Main", read_src("server/LobbyMain.server.lua"))
        put_script(doc, sps, "LocalScript", "Main", read_src("client/LobbyMain.client.lua"))
        put_script(doc, sps, "LocalScript", "LobbyFlicker", read_src("client/LobbyFlicker.client.lua"))
        old = X.child(core, "MonsterAI")
        if old is not None:
            core.remove(old)
    else:
        put_script(doc, core, "ModuleScript", "MonsterAI", read_src("server/MonsterAI.lua"))
        put_script(doc, sss, "Script", "Main", read_src("server/GameMain.server.lua"))
        put_script(doc, sps, "LocalScript", "Main", read_src("client/GameMain.client.lua"))


def sound_groups(root, doc):
    ss = None
    for c in root.findall("Item"):
        if c.get("class") == "SoundService":
            ss = c
    if ss is None:
        ss = X.item(doc, "SoundService", "SoundService", parent=root)
    master = X.child(ss, "Master")
    if master is None:
        master = X.item(doc, "SoundGroup", "Master", [("float", "Volume", 1)], parent=ss)
        X.item(doc, "SoundGroup", "Music", [("float", "Volume", 1)], parent=master)
        X.item(doc, "SoundGroup", "SFX", [("float", "Volume", 1)], parent=master)
    sfx = X.child(master, "SFX")
    if X.child(sfx, "Footsteps") is None:
        steps = X.item(doc, "SoundGroup", "Footsteps", [("float", "Volume", 1)], parent=sfx)
        X.item(doc, "EchoSoundEffect", "Echo", [("float", "Delay", 0.22), ("float", "Feedback", 0.3), ("float", "DryLevel", 0),
                                                ("float", "WetLevel", -7), ("int", "Priority", 1), ("bool", "Enabled", True)], parent=steps)
        X.item(doc, "ReverbSoundEffect", "Reverb", [("float", "DecayTime", 1.6), ("float", "Density", 1), ("float", "Diffusion", 1),
                                                    ("float", "DryLevel", 0), ("float", "WetLevel", -9), ("int", "Priority", 2),
                                                    ("bool", "Enabled", True)], parent=steps)


def build_lobby(check):
    t0 = time.time()
    root = X.load(os.path.join(BASE, "Palata13_Lobby.rbxlx"))
    doc = X.Doc(X.max_referent(root) + 0x1000)
    sc = Scene(doc, seed=13)
    lobby = X.path(root, "Workspace/Lobby")
    lobby_extra.upgrade(sc, lobby)
    install_scripts(root, doc, "lobby")
    sound_groups(root, doc)
    out = os.path.join(DIST, "Palata13_Lobby.rbxlx")
    X.write(root, out)
    print("lobby: +%d parts, wrote %s (%.1f MB) in %.1fs" % (sc.count, out, os.path.getsize(out) / 1e6, time.time() - t0))
    if check:
        verify(out, "lobby")


def build_game(check):
    t0 = time.time()
    root = X.load(os.path.join(BASE, "Palata13_Game.rbxlx"))
    doc = X.Doc(X.max_referent(root) + 0x1000)
    sc = Scene(doc, seed=13)
    ws = X.path(root, "Workspace")
    storage = None
    for c in root.findall("Item"):
        if c.get("class") == "ServerStorage":
            storage = c
    maps = X.child(storage, "Maps") or sc.folder(storage, "Maps")
    # hospital: upgrade + move out of workspace into ServerStorage.Maps
    hospital = X.child(ws, "Map", "Folder")
    hospital_extra.upgrade(sc, hospital)
    ws.remove(hospital)
    X.set_prop(hospital, "string", "Name", "Hospital")
    maps.append(hospital)
    # generated maps
    for modname in ("gen.map_morgue", "gen.map_sanatorium"):
        try:
            mod = importlib.import_module(modname)
        except Exception as e:  # noqa: BLE001 - a half-written map module must not break the build
            print("WARNING: %s not available (%s) - skipping" % (modname, e))
            continue
        before = sc.count
        mod.build(sc, maps)
        print("  %s: %d parts" % (modname, sc.count - before))
    # monsters: both variants; the old single Monster model is replaced
    old = X.child(storage, "Monster", "Model")
    if old is not None:
        storage.remove(old)
    monsters = X.child(storage, "Monsters") or sc.folder(storage, "Monsters")
    build_monster(sc, monsters, "Patient", "Patient")
    build_monster(sc, monsters, "Blind", "Blind")
    # a dark placeholder floor while the map loads (players spawn only after the map is cloned)
    sc.part(ws, "Void", X.CF.new(0, -60, 0), (2048, 2, 2048), (6, 6, 6), material="Slate")
    install_scripts(root, doc, "game")
    sound_groups(root, doc)
    out = os.path.join(DIST, "Palata13_Game.rbxlx")
    X.write(root, out)
    print("game: +%d parts, wrote %s (%.1f MB) in %.1fs" % (sc.count, out, os.path.getsize(out) / 1e6, time.time() - t0))
    if check:
        verify(out, "game")


def verify(path, place):
    root = X.load(path)
    refs = [e.get("referent") for e in root.iter("Item")]
    assert len(refs) == len(set(refs)), "duplicate referents in " + path
    # every Ref property must point at an existing referent
    known = set(refs)
    bad = 0
    for e in root.iter("Ref"):
        if e.text and e.text != "null" and e.text not in known:
            bad += 1
    assert bad == 0, "%d dangling Ref properties" % bad
    required = {
        "lobby": ["Workspace/Lobby/Gates/Gate1", "Workspace/Lobby/MenuMonster", "Workspace/Lobby/MenuScene",
                  "Workspace/Lobby/LightsPrompt", "Workspace/Lobby/PharmacyPrompt", "Workspace/Lobby/TitlesPrompt",
                  "Workspace/Lobby/MapsPrompt", "Workspace/Lobby/Console1", "Workspace/Lobby/MenuMonsterPoints/P4",
                  "ServerScriptService/Main", "StarterPlayer/StarterPlayerScripts/Main", "ReplicatedStorage/Shared/Config",
                  "SoundService/Master/Music"],
        "game": ["ServerStorage/Maps/Hospital/Generators", "ServerStorage/Monsters/Patient/Head/FaceCam",
                 "ServerStorage/Monsters/Blind/HumanoidRootPart", "ServerScriptService/Core/MonsterAI",
                 "ServerScriptService/Main", "StarterPlayer/StarterPlayerScripts/Main", "SoundService/Master/SFX"],
    }[place]
    for p in required:
        assert X.path(root, p) is not None, "missing %s in %s" % (p, path)
    if place == "game":
        maps = X.path(root, "ServerStorage/Maps")
        for m in maps.findall("Item"):
            gens = X.path(m, "Generators")
            n = len(gens.findall("Item")) if gens is not None else 0
            print("  map %-11s generators=%d items=%d" % (X.get_name(m), n, sum(1 for _ in m.iter("Item"))))
            for req in ("Lockers", "Spawns/Fuse", "Spawns/Battery", "AINodes", "SpawnLocation", "MonsterSpawn", "Lights"):
                assert X.path(m, req) is not None, "map %s missing %s" % (X.get_name(m), req)
            assert X.path(m, "ExitGate") is not None or X.path(m, "ExitGates") is not None
            assert X.path(m, "ExitZone") is not None or X.path(m, "ExitZones") is not None
    scripts = [e for e in root.iter("Item") if e.get("class") in ("Script", "LocalScript", "ModuleScript")]
    print("  %s verified: %d items, %d scripts" % (place, len(refs), len(scripts)))


if __name__ == "__main__":
    os.makedirs(DIST, exist_ok=True)
    check = "--check" in sys.argv
    which = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not which or "lobby" in which:
        build_lobby(check)
    if not which or "game" in which:
        build_game(check)
