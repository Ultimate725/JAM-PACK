"""Preview/validate a map generator module:  python3 tools/preview_map.py gen.map_morgue /tmp/out
Builds the map into a fresh document, writes <out>_top.png (+ _side.png), prints stats and runs the
structural checks the game scripts rely on. Exit code 1 if a check fails."""
import importlib
import os
import sys
import collections
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from buildkit import rbxml as X  # noqa: E402
from buildkit.kit import Scene  # noqa: E402
from buildkit import render  # noqa: E402

REQUIRED = ["Structure", "Decor", "Lights", "Lockers", "Spawns/Fuse", "Spawns/Battery", "AINodes", "SpawnLocation",
            "Generators", "MonsterSpawn"]


def validate(mapfolder):
    problems = []
    for p in REQUIRED:
        if X.path(mapfolder, p) is None:
            problems.append("missing " + p)
    if X.path(mapfolder, "ExitGate") is None and X.path(mapfolder, "ExitGates") is None:
        problems.append("missing ExitGate(s)")
    if X.path(mapfolder, "ExitZone") is None and X.path(mapfolder, "ExitZones") is None:
        problems.append("missing ExitZone(s)")
    gens = X.path(mapfolder, "Generators")
    if gens is not None:
        n = 0
        for g in gens.findall("Item"):
            n += 1
            if X.path(g, "Slot") is None:
                problems.append("generator without Slot: " + str(X.get_name(g)))
        if n < 3:
            problems.append("need >= 3 generators, have %d" % n)
    lk = X.path(mapfolder, "Lockers")
    if lk is not None:
        for l in lk.findall("Item"):
            if X.path(l, "Door") is None or X.path(l, "Inside") is None:
                problems.append("locker without Door/Inside")
        if len(lk.findall("Item")) < 6:
            problems.append("need >= 6 lockers")
    for name, minimum in (("Spawns/Fuse", 10), ("Spawns/Battery", 14), ("AINodes", 40)):
        f = X.path(mapfolder, name)
        if f is not None and len(f.findall("Item")) < minimum:
            problems.append("%s has %d entries (< %d)" % (name, len(f.findall("Item")), minimum))
    lights = X.path(mapfolder, "Lights")
    if lights is not None:
        kinds = collections.Counter(X.get_name(c) for c in lights.findall("Item"))
        if kinds["Lamp"] + kinds["FlickerLamp"] < 15:
            problems.append("too few lamps: %s" % dict(kinds))
    refs = [e.get("referent") for e in mapfolder.iter("Item")]
    if len(refs) != len(set(refs)):
        problems.append("duplicate referents")
    return problems


def main():
    modname, out = sys.argv[1], sys.argv[2]
    mod = importlib.import_module(modname)
    doc = X.Doc()
    sc = Scene(doc, seed=13)
    root = ET.Element("roblox")
    root.set("version", "4")
    holder = X.item(doc, "Folder", "Maps", parent=root)
    mp = mod.build(sc, holder)
    counts = collections.Counter(e.get("class") for e in mp.iter("Item"))
    print("map:", X.get_name(mp), "parts:", sc.count, "items:", sum(counts.values()))
    for f in mp.findall("Item"):
        print("  %-14s %5d children" % (X.get_name(f), len(f.findall("Item"))))
    parts = render.collect(mp)
    xs = [cf.p.x for _, cf, _ in parts]
    ys = [cf.p.y for _, cf, _ in parts]
    zs = [cf.p.z for _, cf, _ in parts]
    print("bbox x %.0f..%.0f  y %.0f..%.0f  z %.0f..%.0f" % (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
    ceiling_y = getattr(mod, "CEILING_Y", 11.5)
    render.topdown(mp, out + "_top.png", scale=getattr(mod, "PREVIEW_SCALE", 3), y_range=(-50, ceiling_y),
                   pred=lambda e: X.get_name(e) not in ("Ceiling", "Roof"))
    problems = validate(mp)
    X.write(root, out + ".rbxlx")
    if problems:
        print("PROBLEMS:")
        for p in problems:
            print("  -", p)
        sys.exit(1)
    print("validation OK")


if __name__ == "__main__":
    main()
