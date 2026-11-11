"""Shared prop kit for the Palata 13 maps (hospital / morgue / sanatorium) and the lobby.
Every function appends parts under `parent` and returns the main element. Conventions:
  - a prop's `cf` is its floor-level center; the prop faces -Z of `cf` (Roblox LookVector)
  - lights go into the map's `Lights` folder with names Lamp / FlickerLamp / Emergency
  - names that scripts rely on: Locker{Door,Inside}, Generator{Slot,I1..,Engine}, ExitGate, ExitZone,
    SpawnLocation, MonsterSpawn, AINodes/Node, Spawns/Fuse|Battery/Spawn, SignText/SignStyle values
"""
import math
from buildkit.cframe import CF, V3
from buildkit import rbxml as X

# palette ------------------------------------------------------------------------
WALL = (150, 156, 144)
WALL_DIRTY = (118, 128, 116)
WAINSCOT = (58, 84, 72)
FLOOR = (84, 80, 74)
TILE = (158, 152, 138)
CEIL = (150, 150, 142)
CONCRETE = (96, 96, 92)
STEEL = (150, 150, 145)
RUST = (104, 72, 52)
RUST_DARK = (70, 46, 34)
WOOD = (92, 68, 46)
WOOD_DARK = (58, 42, 30)
BLOOD = (90, 6, 8)
BLOOD_DARK = (52, 4, 6)
GLASS = (170, 190, 200)
PAPER = (205, 198, 180)
BLACK = (14, 12, 12)
LINEN = (190, 186, 172)
MATTRESS = (120, 118, 104)
WARM = (255, 214, 170)
COLD = (150, 170, 200)
NEON_RED = (255, 60, 60)
GREEN = (60, 255, 90)
BRASS = (160, 130, 70)

HALF_PI = math.pi / 2


def at(cf, x=0.0, y=0.0, z=0.0, ry=0.0, rx=0.0, rz=0.0):
    """Offset+rotate relative to prop frame."""
    out = cf * CF.new(x, y, z)
    if ry or rx or rz:
        out = out * CF.angles(rx, ry, rz)
    return out


# -- structure -------------------------------------------------------------------
def wall(sc, parent, a, b, height, thickness=1.0, color=WALL, material="Concrete", y0=0.0, name="Wall", wainscot=None):
    """Wall from point a to b (XZ), bottom at y0."""
    a, b = V3(a[0], y0, a[1]), V3(b[0], y0, b[1])
    d = b - a
    mid = a + d * 0.5 + V3(0, height / 2, 0)
    cf = CF.lookat(mid, mid + V3(-d.z, 0, d.x)) if d.mag > 1e-6 else CF(mid)
    w = sc.part(parent, name, cf, (d.mag, height, thickness), color, material=material)
    if wainscot:
        wcol, wh = wainscot
        for side in (-1, 1):
            sc.part(parent, "Wainscot", cf * CF.new(0, -height / 2 + wh / 2, side * (thickness / 2 + 0.12)),
                    (d.mag, wh, 0.25), wcol, material="SmoothPlastic")
    return w


def slab(sc, parent, name, x0, z0, x1, z1, y, thick, color, material):
    cf = CF.new((x0 + x1) / 2, y, (z0 + z1) / 2)
    return sc.part(parent, name, cf, (abs(x1 - x0), thick, abs(z1 - z0)), color, material=material)


def door_frame(sc, parent, cf, width=8.0, height=11.0, color=WOOD_DARK):
    """Door opening frame; cf = floor center of the opening, opening spans X."""
    sc.part(parent, "Frame", at(cf, -width / 2 - 0.2, height / 2, 0), (0.4, height, 1.3), color, material="Wood")
    sc.part(parent, "Frame", at(cf, width / 2 + 0.2, height / 2, 0), (0.4, height, 1.3), color, material="Wood")
    return sc.part(parent, "Header", at(cf, 0, height + 0.25, 0), (width + 0.8, 0.5, 1.3), color, material="Wood")


def door(sc, parent, cf, width=3.6, height=10.4, open_angle=0.0, color=(96, 110, 96), glass=True, name="DoorLeaf"):
    """Hinged door leaf (non-collidable like the base map: players and the monster walk through);
    hinge at -X edge; open_angle rotates it into +Z. Put two leaves side by side for an 8-wide opening."""
    hinge = at(cf, -width / 2, 0, 0) * CF.rot_y(open_angle)
    leaf = sc.part(parent, name, hinge * CF.new(width / 2, height / 2, 0), (width, height, 0.25), color, material="Wood", collide=False)
    if glass:
        sc.part(parent, "DoorGlass", hinge * CF.new(width / 2, height * 0.68, 0), (width * 0.45, height * 0.3, 0.3), GLASS,
                material="Glass", transparency=0.5, collide=False)
    sc.part(parent, "Kick", hinge * CF.new(width / 2, 0.5, 0), (width, 1.0, 0.32), STEEL, material="DiamondPlate", collide=False)
    sc.part(parent, "Handle", hinge * CF.new(width - 0.6, height * 0.45, 0.25), (0.5, 0.15, 0.3), STEEL, material="Metal", collide=False)
    return leaf


# -- lights ------------------------------------------------------------------------
def ceiling_lamp(sc, lights, pos, kind="Lamp", color=WARM, size=(5, 0.25, 1.1), range_=22, brightness=0.9, rot=0.0):
    cf = CF(pos) * CF.rot_y(rot)
    p = sc.part(lights, kind, cf, size, (230, 225, 205) if kind != "Emergency" else NEON_RED, material="Neon",
                collide=False, cast_shadow=False)
    sc.part(lights, "Housing", cf * CF.new(0, 0.22, 0), (size[0] + 0.4, 0.2, size[2] + 0.4), (60, 58, 54), material="Metal", collide=False)
    sc.surfacelight(p, "Bottom", 100, range_, brightness, color)
    return p


def emergency_light(sc, lights, cf):
    p = sc.part(lights, "Emergency", cf, (1, 0.5, 0.5), NEON_RED, material="Neon", collide=False, cast_shadow=False)
    sc.pointlight(p, NEON_RED, 14, 0.6, False)
    return p


def wall_lamp(sc, lights, cf, kind="FlickerLamp", color=WARM):
    """Caged bulb on a wall, cf facing out of the wall."""
    cage = sc.part(lights, kind, at(cf, 0, 0, 0.45), (0.8, 1.2, 0.8), (235, 225, 200), material="Neon", collide=False, cast_shadow=False)
    sc.pointlight(cage, color, 16, 0.8, True)
    return cage


# -- hiding spots --------------------------------------------------------------------
def locker(sc, lockers, cf, color=(92, 104, 96)):
    """Metal locker; door faces -Z of cf. Script needs Door + Inside."""
    m = sc.model(lockers, "Locker")
    w, h, d = 3.0, 7.2, 2.4
    sc.part(m, "Back", at(cf, 0, h / 2, d / 2), (w, h, 0.2), color, material="Metal")
    for sx in (-1, 1):
        sc.part(m, "Side", at(cf, sx * (w / 2 - 0.1), h / 2, 0), (0.2, h, d), color, material="Metal")
    sc.part(m, "Top", at(cf, 0, h - 0.1, 0), (w, 0.2, d), color, material="Metal")
    sc.part(m, "Bottom", at(cf, 0, 0.1, 0), (w, 0.2, d), color, material="Metal")
    sc.part(m, "Door", at(cf, 0, h / 2, -d / 2), (w - 0.2, h - 0.2, 0.2), sc.vary(color, 8), material="Metal")
    for i in range(5):
        sc.part(m, "Vent", at(cf, 0, h - 1.3 - i * 0.4, -d / 2 - 0.12), (1.4, 0.12, 0.08), (40, 44, 40), material="Metal", collide=False)
    sc.part(m, "Handle", at(cf, w / 2 - 0.5, h / 2, -d / 2 - 0.2), (0.15, 0.9, 0.2), STEEL, material="Metal", collide=False)
    sc.part(m, "Inside", at(cf, 0, 3.2, 0.2), (1, 1, 1), (255, 0, 0), transparency=1, collide=False, can_query=False)
    return m


def wardrobe(sc, lockers, cf, color=WOOD_DARK):
    """Wooden wardrobe hiding spot (sanatorium)."""
    m = locker(sc, lockers, cf, color)
    # replace vents look: wooden panel lines
    for c in m.findall("Item"):
        if X.get_name(c) in ("Vent",):
            X.set_prop(c, "Color3uint8", "Color3uint8", (48, 34, 24))
        elif X.get_name(c) in ("Back", "Side", "Top", "Bottom", "Door"):
            X.set_prop(c, "token", "Material", X.MAT["WoodPlanks"])
    return m


# -- objectives -----------------------------------------------------------------------
def generator(sc, parent, cf, indicators=4, style="diesel"):
    """Generator model: Slot (prompt), I1..In indicators, Engine (sound), Sparks emitter, lamp enabled on repair."""
    m = sc.model(parent, "Generator")
    body_col = (70, 64, 58) if style == "diesel" else (58, 62, 70)
    sc.part(m, "Base", at(cf, 0, 0.3, 0), (10, 0.6, 6), (50, 48, 46), material="DiamondPlate")
    body = sc.part(m, "Body", at(cf, 0, 3.6, 0), (9, 6, 5), body_col, material="CorrodedMetal")
    sc.part(m, "Tank", at(cf, 0, 7.6, 0), (8.6, 2.2, 2.2), (86, 72, 60), material="CorrodedMetal", shape="Cylinder")
    for i in range(4):
        sc.part(m, "Fin", at(cf, -3.2 + i * 2.1, 3.6, -2.6), (1.4, 5.2, 0.2), (56, 52, 48), material="Metal", collide=False)
    sc.part(m, "Exhaust", at(cf, 3.5, 7.2, 1.8) * CF.rot_z(HALF_PI), (6, 1, 1), RUST, material="CorrodedMetal", shape="Cylinder")
    engine = sc.part(m, "Engine", at(cf, 3.5, 10.3, 1.8), (1, 1, 1), BLACK, transparency=1, collide=False, can_query=False)
    ex = sc.smoke(engine, color=(40, 36, 34), rate=12, size=(1, 3.5), lifetime=(1.5, 3), speed=(3, 6), transparency=0.5)
    X.set_prop(ex, "bool", "Enabled", False)
    X.set_prop(ex, "string", "Name", "Exhaust")
    panel = sc.part(m, "Panel", at(cf, 0, 3.8, -2.65), (5, 3.4, 0.3), (40, 44, 48), material="Metal")
    slot = sc.part(m, "Slot", at(cf, 0, 3.0, -2.95), (2.2, 1.6, 0.4), (30, 30, 32), material="Metal")
    sc.sparks(slot, rate=0)
    for i in range(indicators):
        p = sc.part(m, "I%d" % (i + 1), at(cf, -1.8 + i * (3.6 / max(1, indicators - 1)), 5.0, -2.85), (0.4, 0.4, 0.2),
                    (120, 10, 10), material="Neon", collide=False)
        sc.pointlight(p, GREEN, 6, 0.0, False)
    warn = sc.part(m, "Warn", at(cf, 0, 6.9, -2.55), (5, 0.6, 0.05), (230, 200, 60), material="SmoothPlastic", collide=False)
    sc.sign(warn, "ГЕНЕРАТОР · ВЫСОКОЕ НАПРЯЖЕНИЕ", "plain")
    for i in range(8):
        sc.part(m, "Stripe", at(cf, -4.4 + i * 1.25, 0.65, -3.03), (0.6, 0.6, 0.06), (230, 200, 60) if i % 2 else BLACK,
                material="SmoothPlastic", collide=False)
    sc.cyl(m, "Cable", at(cf, -4.5, 1.2, 1.5).p, at(cf, -9, 0.3, 4).p, 0.12, BLACK, collide=False)
    sc.cyl(m, "Cable", at(cf, 4.5, 1.2, 1.2).p, at(cf, 9, 0.3, 3).p, 0.12, BLACK, collide=False)
    lamp = sc.part(m, "WorkLamp", at(cf, -3.5, 7.4, -2.2), (0.8, 0.5, 0.8), (255, 200, 120), material="Neon", collide=False)
    wl = sc.spotlight(lamp, "Bottom", 110, 24, 2.5, (255, 200, 120), True)
    X.set_prop(wl, "bool", "Enabled", False)
    _ = (body, panel)
    return m


def exit_gate(sc, parent, cf, width=22.0, height=12.0, style="iron"):
    """Barred gate; opens by sliding down (script default offset (0,-13,0)). Faces -Z."""
    m = sc.model(parent, "ExitGate")
    n = int(width / 1.0)
    for i in range(n):
        x = -width / 2 + 0.5 + i * (width / n)
        sc.part(m, "Bar", at(cf, x, height / 2, 0), (0.3, height, 0.3), RUST_DARK if style == "iron" else STEEL,
                material="CorrodedMetal" if style == "iron" else "Metal")
        if style == "iron":
            tip = sc.part(m, "Spike", at(cf, x, height + 0.5, 0), (0.3, 1.0, 0.3), RUST_DARK, material="CorrodedMetal", collide=False)
            sc.mesh(tip, "Wedge")
    for y in (1.0, height / 2, height - 1.0):
        sc.part(m, "Rail", at(cf, 0, y, 0), (width, 0.5, 0.5), RUST_DARK if style == "iron" else STEEL,
                material="CorrodedMetal" if style == "iron" else "Metal")
    if style == "grille":
        for j in range(int(height / 1.2)):
            sc.part(m, "Rail", at(cf, 0, 0.6 + j * 1.2, 0), (width, 0.15, 0.15), STEEL, material="Metal", collide=False)
    sc.part(m, "Lock", at(cf, 0, height / 2, -0.4), (1.4, 1.8, 0.8), (60, 56, 52), material="Metal")
    prev = at(cf, -1.5, height / 2 + 1.2, -0.5).p
    for i in range(6):
        nxt = at(cf, -1.5 + i * 0.6, height / 2 + 1.2 - abs(2.5 - i) * 0.35, -0.5).p
        sc.cyl(m, "Chain", prev, nxt, 0.1, RUST, collide=False)
        prev = nxt
    return m


def exit_zone(sc, parent, cf, size=(30, 12, 20)):
    return sc.part(parent, "ExitZone", at(cf, 0, size[1] / 2, 0), size, (0, 255, 0), transparency=1, collide=False, can_query=False)


def marker(sc, parent, name, pos, color=(255, 0, 0), size=(2, 1, 2)):
    return sc.part(parent, name, CF(pos), size, color, transparency=1, collide=False, can_query=False)


def node(sc, nodes, pos):
    return sc.part(nodes, "Node", CF((pos[0], 3.0, pos[2] if len(pos) > 2 else pos[1])), (1, 1, 1), (0, 0, 255),
                   transparency=1, collide=False, can_query=False)


def spawn_point(sc, folder, pos):
    return sc.part(folder, "Spawn", CF(pos), (1, 1, 1), (255, 255, 0), transparency=1, collide=False, can_query=False)


# -- signage / gore ----------------------------------------------------------------------
def writing(sc, decor, cf, text, size=(8, 2.2, 0.08), style="blood"):
    p = sc.part(decor, "Writing", cf, size, (110, 10, 12), material="SmoothPlastic", transparency=1, collide=False)
    sc.sign(p, text, style)
    return p


def room_sign(sc, decor, cf, text, style="room", size=(6, 1.0, 0.1)):
    p = sc.part(decor, "RoomSign", cf, size, (30, 32, 30), material="SmoothPlastic", collide=False)
    sc.sign(p, text, style)
    return p


def exit_sign(sc, decor, cf, text="ВЫХОД"):
    p = sc.part(decor, "ExitSign", cf, (3.2, 1.0, 0.25), (20, 60, 30), material="SmoothPlastic", collide=False)
    sc.sign(p, text, "exit")
    sc.pointlight(p, (120, 255, 150), 8, 0.5, False)
    return p


def blood_pool(sc, decor, pos, radius=2.0):
    cf = CF((pos[0], pos[1] + 0.03, pos[2])) * CF.rot_y(sc.rng.random() * 6.28)
    p = sc.part(decor, "Smear", cf, (radius * 2, 0.05, radius * 1.4), BLOOD_DARK, material="Granite", collide=False, shape="Cylinder" if False else None)
    sc.mesh(p, "Sphere", (1, 0.05, 1))
    for i in range(4):
        q = cf * CF.new(sc.jitter(radius), 0, sc.jitter(radius))
        d = sc.part(decor, "Smear", q, (0.4 + sc.rng.random() * 0.9, 0.04, 0.3 + sc.rng.random() * 0.6), BLOOD, material="Granite", collide=False)
        sc.mesh(d, "Sphere", (1, 0.05, 1))
    return p


def blood_smear(sc, decor, cf, length=3.0):
    """Hand-smear on a wall; cf on wall surface facing out."""
    for i in range(5):
        q = at(cf, sc.jitter(0.4) - length / 2 + i * length / 5, sc.jitter(0.5), 0.03, rz=sc.jitter(0.5))
        sc.part(decor, "Smear", q, (length / 4 + 0.3, 0.3 + sc.rng.random() * 0.5, 0.04), BLOOD if i % 2 else BLOOD_DARK,
                material="Granite", collide=False)
    hand = sc.part(decor, "Hand", at(cf, length / 2, 0.2, 0.03), (0.9, 1.1, 0.05), BLOOD, material="Granite", collide=False)
    sc.mesh(hand, "Sphere", (1, 1, 0.5))
    for f in range(4):
        fp = sc.part(decor, "Finger", at(cf, length / 2 - 0.3 + f * 0.22, 0.95, 0.03), (0.16, 0.6, 0.05), BLOOD, material="Granite", collide=False)
        sc.mesh(fp, "Sphere", (1, 1, 0.5))


def papers(sc, decor, pos, n=8, radius=2.5):
    for _ in range(n):
        cf = CF((pos[0] + sc.jitter(radius), pos[1] + 0.03, pos[2] + sc.jitter(radius))) * CF.rot_y(sc.rng.random() * 6.28)
        sc.part(decor, "Part", cf, (1.2, 0.02, 1.6), sc.vary(PAPER, 15), material="SmoothPlastic", collide=False)


def debris(sc, decor, pos, n=6, radius=3.0):
    for _ in range(n):
        cf = CF((pos[0] + sc.jitter(radius), pos[1] + 0.15, pos[2] + sc.jitter(radius))) * CF.angles(sc.jitter(0.4), sc.rng.random() * 6.28, sc.jitter(0.4))
        sc.part(decor, "Part", cf, (0.4 + sc.rng.random() * 1.2, 0.2 + sc.rng.random() * 0.3, 0.3 + sc.rng.random() * 0.9),
                sc.vary(CONCRETE, 20), material="Concrete", collide=False)


# -- furniture --------------------------------------------------------------------------
def bed(sc, decor, cf, bloody=False):
    """Hospital bed 3.2 x 7.5, head at +Z."""
    frame = (120, 124, 120)
    sc.part(decor, "Part", at(cf, 0, 1.9, 0), (3.2, 0.3, 7.4), frame, material="Metal")
    sc.part(decor, "Part", at(cf, 0, 2.35, 0), (3.0, 0.6, 7.0), MATTRESS, material="Fabric")
    sc.part(decor, "Part", at(cf, 0, 2.72, 0.4), (3.0, 0.12, 5.6), sc.vary(LINEN, 10), material="Fabric", collide=False)
    sc.part(decor, "Part", at(cf, 0, 2.95, 3.0), (2.2, 0.5, 1.2), (205, 200, 190), material="Fabric", collide=False)
    for sx in (-1, 1):
        for sz in (-1, 1):
            sc.part(decor, "Part", at(cf, sx * 1.4, 0.95, sz * 3.4), (0.25, 1.9, 0.25), frame, material="Metal")
    sc.part(decor, "Part", at(cf, 0, 3.4, 3.7), (3.2, 2.6, 0.2), (150, 150, 146), material="Metal")
    sc.part(decor, "Part", at(cf, 0, 2.9, -3.7), (3.2, 1.6, 0.2), (150, 150, 146), material="Metal")
    if bloody:
        sc.part(decor, "Smear", at(cf, sc.jitter(0.6), 2.8, sc.jitter(1.5)), (1.4, 0.03, 2.2), BLOOD_DARK, material="Granite", collide=False)
    return cf


def gurney(sc, decor, cf, sheet=True):
    sc.part(decor, "Part", at(cf, 0, 2.6, 0), (2.6, 0.2, 6.6), STEEL, material="Metal")
    if sheet:
        sc.part(decor, "Part", at(cf, 0, 3.0, 0), (2.5, 0.7, 6.2), sc.vary(LINEN, 10), material="Fabric", collide=False)
        sc.part(decor, "Part", at(cf, 0, 3.55, 2.2), (1.3, 0.5, 1.2), LINEN, material="Fabric", collide=False)  # body shape under sheet
    for sx in (-1, 1):
        sc.part(decor, "Part", at(cf, sx * 1.1, 1.4, 0) * CF.rot_x(0.35), (0.15, 2.6, 0.15), STEEL, material="Metal", collide=False)
        sc.part(decor, "Part", at(cf, sx * 1.1, 1.4, 0) * CF.rot_x(-0.35), (0.15, 2.6, 0.15), STEEL, material="Metal", collide=False)
    for sx in (-1, 1):
        for sz in (-1, 1):
            sc.part(decor, "Part", at(cf, sx * 1.1, 0.3, sz * 2.6) * CF.rot_z(HALF_PI), (0.6, 0.6, 0.3), BLACK, material="Rubber" if "Rubber" in X.MAT else "SmoothPlastic", shape="Cylinder", collide=False)
    return cf


def wheelchair(sc, parent, cf, name="Wheelchair"):
    m = sc.model(parent, name)
    sc.part(m, "Seat", at(cf, 0, 1.9, 0), (2.2, 0.25, 2.0), (40, 40, 42), material="Fabric")
    sc.part(m, "Back", at(cf, 0, 3.2, 0.95), (2.2, 2.4, 0.2), (40, 40, 42), material="Fabric")
    for sx in (-1, 1):
        w = sc.part(m, "Wheel", at(cf, sx * 1.25, 1.3, 0.3) * CF.rot_z(HALF_PI), (2.6, 2.6, 0.2), (60, 60, 62), material="Metal", shape="Cylinder")
        for s in range(6):
            sc.part(m, "Spoke", at(cf, sx * 1.25, 1.3, 0.3) * CF.rot_z(HALF_PI) * CF.rot_x(s * math.pi / 6), (0.08, 2.3, 0.08), STEEL, material="Metal", collide=False)
        sc.part(m, "Rim", at(cf, sx * 1.4, 1.3, 0.3) * CF.rot_z(HALF_PI), (2.9, 2.9, 0.08), STEEL, material="Metal", shape="Cylinder", collide=False)
        sc.part(m, "Caster", at(cf, sx * 0.9, 0.4, -1.0) * CF.rot_z(HALF_PI), (0.8, 0.8, 0.2), (30, 30, 30), material="SmoothPlastic", shape="Cylinder", collide=False)
        sc.part(m, "Handle", at(cf, sx * 1.0, 4.2, 1.2), (0.12, 0.12, 0.9), STEEL, material="Metal", collide=False)
        sc.part(m, "Armrest", at(cf, sx * 1.15, 2.8, 0), (0.15, 0.15, 1.8), STEEL, material="Metal", collide=False)
        sc.part(m, "Foot", at(cf, sx * 0.5, 0.7, -1.3), (0.8, 0.1, 0.8), STEEL, material="Metal", collide=False)
        _ = w
    return m


def iv_stand(sc, decor, cf):
    sc.cyl(decor, "Part", at(cf, 0, 0.1, 0).p, at(cf, 0, 7.2, 0).p, 0.08, STEEL, collide=False)
    for a in range(5):
        ang = a * 2 * math.pi / 5
        sc.cyl(decor, "Part", at(cf, 0, 0.15, 0).p, at(cf, math.cos(ang) * 1.1, 0.15, math.sin(ang) * 1.1).p, 0.06, STEEL, collide=False)
    sc.part(decor, "Part", at(cf, 0, 7.2, 0), (1.6, 0.08, 0.08), STEEL, material="Metal", collide=False)
    bag = sc.part(decor, "Part", at(cf, 0.7, 6.3, 0), (0.7, 1.3, 0.3), (210, 200, 180), material="Plastic", transparency=0.35, collide=False)
    sc.mesh(bag, "Sphere", (1, 1, 1))
    sc.cyl(decor, "Part", at(cf, 0.7, 5.6, 0).p, at(cf, 0.9, 2.5, -0.5).p, 0.03, (220, 210, 200), transparency=0.3, collide=False)
    return cf


def cabinet(sc, decor, cf, w=3.0, h=6.0, d=1.6, color=(150, 160, 150), glass=True, open_door=False):
    sc.part(decor, "Part", at(cf, 0, h / 2, 0), (w, h, d), color, material="Metal")
    if glass:
        sc.part(decor, "Part", at(cf, -w / 4 * (1 if not open_door else 0), h * 0.6, -d / 2 - 0.05), (w / 2 - 0.2, h * 0.5, 0.1), GLASS, material="Glass", transparency=0.45, collide=False)
        if open_door:
            sc.part(decor, "Part", at(cf, w / 2, h * 0.6, -d / 2, ry=-1.2) * CF.new(w / 4, 0, 0), (w / 2 - 0.2, h * 0.5, 0.1), GLASS, material="Glass", transparency=0.45, collide=False)
        else:
            sc.part(decor, "Part", at(cf, w / 4, h * 0.6, -d / 2 - 0.05), (w / 2 - 0.2, h * 0.5, 0.1), GLASS, material="Glass", transparency=0.45, collide=False)
    for i in range(3):
        sc.part(decor, "Part", at(cf, 0, h * 0.35 + i * h * 0.18, -d / 2 + 0.3), (w - 0.4, 0.06, d - 0.5), (120, 125, 120), material="Metal", collide=False)
        for k in range(3):
            if sc.chance(0.6):
                sc.part(decor, "Part", at(cf, -w / 3 + k * w / 3, h * 0.35 + i * h * 0.18 + 0.35, -d / 2 + 0.35), (0.3, 0.6, 0.3),
                        sc.pick([(200, 190, 160), (120, 60, 50), (90, 120, 100), (230, 230, 220)]), material="Glass", transparency=0.2, collide=False)
    return cf


def desk(sc, decor, cf, w=5.0, d=2.4, color=WOOD, with_chair=True, clutter=True):
    sc.part(decor, "Part", at(cf, 0, 2.5, 0), (w, 0.2, d), color, material="Wood")
    for sx in (-1, 1):
        sc.part(decor, "Part", at(cf, sx * (w / 2 - 0.3), 1.25, 0), (0.5, 2.5, d - 0.2), sc.vary(color, 6), material="Wood")
    if clutter:
        sc.part(decor, "Part", at(cf, -w / 4, 2.75, 0.2), (1.4, 0.3, 1.0), PAPER, material="SmoothPlastic", collide=False)
        lamp = sc.part(decor, "Part", at(cf, w / 3, 3.4, 0.5), (0.5, 1.6, 0.5), (40, 60, 40), material="Metal", collide=False)
        sc.part(decor, "Part", at(cf, w / 3, 4.2, 0.2) * CF.rot_x(0.3), (1.2, 0.5, 1.2), (40, 60, 40), material="Metal", collide=False)
        _ = lamp
        papers(sc, decor, at(cf, 0, 2.6, 0).p, n=3, radius=1.0)
    if with_chair:
        chair(sc, decor, at(cf, 0.4, 0, 2.2, ry=math.pi + sc.jitter(0.4)))
    return cf


def chair(sc, decor, cf, color=(60, 70, 64), fallen=False):
    base = cf if not fallen else cf * CF.new(0, 0.6, 0) * CF.rot_z(HALF_PI)
    sc.part(decor, "Part", at(base, 0, 1.7, 0), (1.8, 0.2, 1.8), color, material="Fabric")
    sc.part(decor, "Part", at(base, 0, 2.8, 0.8), (1.8, 2.0, 0.2), color, material="Fabric")
    for sx in (-1, 1):
        for sz in (-1, 1):
            sc.part(decor, "Part", at(base, sx * 0.75, 0.8, sz * 0.75), (0.12, 1.6, 0.12), STEEL, material="Metal", collide=False)
    return cf


def sink(sc, decor, cf):
    sc.part(decor, "Part", at(cf, 0, 3.0, 0), (2.2, 0.6, 1.6), (225, 225, 220), material="SmoothPlastic")
    sc.part(decor, "Part", at(cf, 0, 1.5, 0.5), (0.8, 2.6, 0.5), (200, 200, 198), material="SmoothPlastic")
    sc.part(decor, "Part", at(cf, 0, 3.6, 0.6), (0.12, 0.8, 0.12), STEEL, material="Metal", collide=False)
    sc.part(decor, "Part", at(cf, 0, 4.0, 0.3), (0.12, 0.12, 0.7), STEEL, material="Metal", collide=False)
    sc.part(decor, "Part", at(cf, 0, 5.5, 0.85), (2.0, 2.4, 0.1), (60, 70, 80), material="Glass", reflectance=0.35)
    sc.part(decor, "Smear", at(cf, 0.3, 3.32, -0.2), (0.8, 0.03, 0.6), BLOOD_DARK, material="Granite", collide=False)
    return cf


def toilet(sc, decor, cf):
    sc.part(decor, "Part", at(cf, 0, 1.0, 0), (1.6, 2.0, 2.2), (220, 220, 215), material="SmoothPlastic")
    sc.part(decor, "Part", at(cf, 0, 2.6, 1.0), (1.6, 2.0, 0.8), (220, 220, 215), material="SmoothPlastic")
    sc.part(decor, "Part", at(cf, 0, 2.1, -0.2), (1.4, 0.15, 1.6), (40, 40, 40), material="SmoothPlastic", collide=False)
    return cf


def shelf(sc, decor, cf, w=4.0, h=7.0, d=1.2, color=(110, 110, 104)):
    for sx in (-1, 1):
        sc.part(decor, "Part", at(cf, sx * (w / 2), h / 2, 0), (0.15, h, d), color, material="Metal")
    for i in range(4):
        y = 0.6 + i * (h - 0.8) / 3
        sc.part(decor, "Part", at(cf, 0, y, 0), (w, 0.12, d), color, material="Metal")
        for k in range(4):
            if sc.chance(0.65):
                sc.part(decor, "Part", at(cf, -w / 2 + 0.5 + k * (w - 1) / 3, y + 0.5, sc.jitter(0.2)), (0.6, 0.9, 0.5),
                        sc.pick([(150, 120, 80), (90, 90, 95), (180, 180, 170), (120, 50, 40)]), material="Cardboard" if "Cardboard" in X.MAT else "Wood", collide=False)
    return cf


def barrel(sc, decor, cf, color=(70, 90, 60)):
    b = sc.part(decor, "Part", at(cf, 0, 1.75, 0) * CF.rot_z(HALF_PI), (3.5, 2.4, 2.4), color, material="CorrodedMetal", shape="Cylinder")
    for y in (0.6, 1.75, 2.9):
        sc.part(decor, "Part", at(cf, 0, y, 0) * CF.rot_z(HALF_PI), (0.2, 2.55, 2.55), (50, 50, 48), material="Metal", shape="Cylinder", collide=False)
    return b


def crate(sc, decor, cf, size=2.4, color=WOOD):
    sc.part(decor, "Part", at(cf, 0, size / 2, 0) * CF.rot_y(sc.jitter(0.3)), (size, size, size), sc.vary(color, 8), material="WoodPlanks")
    return cf


def pipe_run(sc, parent, points, radius=0.35, color=RUST, material="CorrodedMetal"):
    for a, b in zip(points, points[1:]):
        sc.cyl(parent, "Pipe", a, b, radius, color, material=material, collide=False)
        sc.ball(parent, "Pipe", b, radius * 2.2, color, material=material, collide=False)


def vent(sc, decor, cf, w=2.0, h=1.2):
    sc.part(decor, "Part", cf, (w, h, 0.15), (90, 92, 88), material="Metal", collide=False)
    for i in range(int(h / 0.25)):
        sc.part(decor, "Part", at(cf, 0, -h / 2 + 0.15 + i * 0.25, -0.1), (w - 0.3, 0.08, 0.08), (30, 30, 30), material="Metal", collide=False)


def extinguisher(sc, decor, cf):
    sc.part(decor, "Part", at(cf, 0, 3.2, 0.3) * CF.rot_z(HALF_PI), (2.0, 0.7, 0.7), (170, 20, 20), material="SmoothPlastic", shape="Cylinder", collide=False)
    sc.part(decor, "Part", at(cf, 0, 4.4, 0.3), (0.3, 0.5, 0.3), BLACK, material="Metal", collide=False)
    sc.part(decor, "Part", at(cf, 0, 3.2, 0.05), (1.0, 2.4, 0.1), (150, 20, 20), material="SmoothPlastic", collide=False)


def poster(sc, decor, cf, text, style="plain", size=(3.0, 2.0)):
    p = sc.part(decor, "Board", cf, (size[0], size[1], 0.08), sc.vary(PAPER, 20), material="SmoothPlastic", collide=False)
    sc.sign(p, text, style)
    return p


def body_bag(sc, decor, cf, open_=False):
    sc.part(decor, "Part", at(cf, 0, 0.45, 0), (2.4, 0.9, 6.4), (24, 24, 26), material="Fabric", collide=False)
    sc.part(decor, "Part", at(cf, 0, 0.9, 1.4), (1.4, 0.4, 1.3), (24, 24, 26), material="Fabric", collide=False)
    if open_:
        face = sc.part(decor, "Part", at(cf, 0, 0.95, 2.0), (0.9, 0.5, 1.0), (190, 180, 160), material="SmoothPlastic", collide=False)
        sc.mesh(face, "Sphere")


def hanging_body_sheet(sc, decor, cf, h=7.0):
    """Sheet-covered shape hanging from the ceiling (hook)."""
    sc.cyl(decor, "Part", at(cf, 0, h + 1.5, 0).p, at(cf, 0, h, 0).p, 0.05, RUST, collide=False)
    sc.part(decor, "Part", at(cf, 0, h - 2.6, 0), (1.9, 5.4, 1.2), sc.vary(LINEN, 10), material="Fabric", collide=False)
    sc.part(decor, "Part", at(cf, 0, h - 0.4, 0), (1.2, 1.0, 1.0), (205, 200, 190), material="Fabric", collide=False)


def candle(sc, decor, lights, pos):
    c = sc.part(decor, "Part", CF((pos[0], pos[1] + 0.35, pos[2])) * CF.rot_z(HALF_PI), (0.7, 0.3, 0.3), (230, 220, 190), material="SmoothPlastic", shape="Cylinder", collide=False)
    f = sc.part(lights, "Emergency", CF((pos[0], pos[1] + 0.85, pos[2])), (0.15, 0.25, 0.15), (255, 170, 60), material="Neon", collide=False, cast_shadow=False)
    sc.pointlight(f, (255, 150, 60), 9, 0.7, True)
    _ = c


def tree(sc, decor, pos, height=28.0, trunk_r=1.1, seed=None):
    """Dead/pine hybrid tree: trunk + branches + twigs, no leaves (fog does the rest)."""
    rng = sc.rng
    base = V3(pos[0], pos[1], pos[2])
    top = base + V3(rng.random() * 2 - 1, height, rng.random() * 2 - 1)
    sc.cyl(decor, "Trunk", base - V3(0, 1, 0), top, trunk_r, (54, 44, 36), material="Wood")
    sc.cyl(decor, "Trunk", base - V3(0, 1, 0), base + V3(0, height * 0.35, 0), trunk_r * 1.25, (48, 40, 32), material="Wood")
    nb = 6 + rng.randrange(5)
    for i in range(nb):
        t = 0.3 + 0.65 * (i / nb)
        start = base.lerp(top, t)
        ang = rng.random() * 6.28
        length = (1 - t) * 10 + 3
        end = start + V3(math.cos(ang) * length, 1.5 + rng.random() * 3, math.sin(ang) * length)
        sc.cyl(decor, "Branch", start, end, trunk_r * 0.35 * (1 - t * 0.5), (50, 42, 34), material="Wood", collide=False)
        for _ in range(2):
            a2 = ang + rng.random() * 1.4 - 0.7
            mid = start.lerp(end, 0.5 + rng.random() * 0.4)
            e2 = mid + V3(math.cos(a2) * length * 0.5, 0.5 + rng.random() * 2, math.sin(a2) * length * 0.5)
            sc.cyl(decor, "Twig", mid, e2, 0.12, (46, 38, 30), material="Wood", collide=False)


def lamp_post(sc, decor, lights, pos, on_power=True):
    base = V3(*pos)
    sc.cyl(decor, "Post", base, base + V3(0, 14, 0), 0.25, (40, 40, 42), material="Metal")
    sc.part(decor, "Post", CF(base + V3(0, 14.2, -0.8)), (0.3, 0.3, 2.0), (40, 40, 42), material="Metal", collide=False)
    head = sc.part(lights, "Lamp" if on_power else "FlickerLamp", CF(base + V3(0, 13.9, -1.7)), (1.4, 0.4, 1.4), (230, 225, 200), material="Neon", collide=False, cast_shadow=False)
    sc.part(decor, "Housing", CF(base + V3(0, 14.3, -1.7)), (1.8, 0.4, 1.8), (36, 36, 38), material="Metal", collide=False)
    sc.surfacelight(head, "Bottom", 120, 28, 0.9, (255, 220, 170))
    return head


def fence_run(sc, decor, a, b, height=9.0, spacing=1.0, color=RUST_DARK):
    a, b = V3(*a), V3(*b)
    d = b - a
    n = max(1, int(d.mag / spacing))
    for i in range(n + 1):
        p = a + d * (i / n)
        sc.part(decor, "Bar", CF(p + V3(0, height / 2, 0)), (0.25, height, 0.25), color, material="CorrodedMetal")
    mid = a + d * 0.5
    cf = CF.lookat(mid, mid + V3(-d.z, 0, d.x))
    for y in (1.0, height - 1.0):
        sc.part(decor, "Rail", cf * CF.new(0, y, 0), (d.mag, 0.3, 0.3), color, material="CorrodedMetal")
    for i in range(0, n + 1, max(1, n // 6)):
        p = a + d * (i / n)
        sc.part(decor, "Pillar", CF(p + V3(0, height / 2 + 0.3, 0)), (1.4, height + 0.6, 1.4), (70, 68, 64), material="Brick")
