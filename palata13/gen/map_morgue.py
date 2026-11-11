"""МОРГ: the morgue beneath the hospital (procedural map for Palata 13).

Story: the night staff vanished the evening Patient 13 was to be cremated. The drawers knock from
inside, the furnace is still warm and the freight elevator has no power.

Layout (x east, z south, floor top y=0, ceiling y=11):

        -110     -62   -20     20    62     110
   -90   +--BOIL--+-AUTO-+-LAUN-+-OFFC-+--ELEV--+      ring corridor loop (12 wide) around the island
   -40   +--CHAP--+==========RN===========+-WORK--+      COLD (monster) | CREM sit in the island
     0   +--ARCH--+ RW  [COLD | CREM]  RE +-RECEP-+      TUN = flooded tunnel (floor y=-1.5)
    40   +-STAIR--+-LOCK-+ RS  SPUR       +--PUMP--+
    90   spawn: STAIR   generators: BOIL, LAUN, WORK, PUMP   exit: ELEV (freight elevator)
"""
import math
import heapq

from buildkit.cframe import CF, V3
from gen import props as P
from gen.props import at

CEILING_Y = 10.5
PREVIEW_SCALE = 6

PI = math.pi
HALF_PI = PI / 2
H = 11.0            # clear height (floor top -> ceiling underside)
INSET = 0.78        # wall centre line -> flush face for wall-hugging props (half wall + wainscot)
DOOR_W = 8.0
NAV_R = 2.4         # monster agent radius used by the layout self-check
NEUTRAL_WALL = (112, 118, 108)

# ------------------------------------------------------------------------------------ palette
TEAL = (84, 108, 98)
TILE_LIGHT = (168, 178, 172)
BRICK = (112, 62, 50)
STEEL = P.STEEL
DARK_STEEL = (54, 58, 60)
LINEN = P.LINEN
BLOOD = P.BLOOD
BLOOD_DARK = P.BLOOD_DARK
HAZ_Y = (226, 190, 40)
HAZ_K = (22, 22, 20)


def _sty(wall, tile, th, floor, fmat, ceil, grout=None, wmat="Concrete"):
    return {"wall": wall, "tile": tile, "th": th, "floor": floor, "fmat": fmat, "ceil": ceil, "grout": grout, "wmat": wmat}


STY = {
    "ring": _sty((112, 118, 108), TEAL, 3.4, (92, 94, 90), "SmoothPlastic", (96, 98, 92), (5.0, (46, 50, 48))),
    "stair": _sty((100, 98, 90), (82, 88, 80), 2.4, (72, 70, 66), "Concrete", (88, 88, 84)),
    "arch": _sty((134, 122, 98), (96, 82, 62), 3.2, (94, 78, 58), "WoodPlanks", (112, 106, 94)),
    "chap": _sty((114, 106, 98), (72, 60, 54), 4.2, (96, 92, 88), "Slate", (98, 92, 86), (6.0, (58, 54, 50))),
    "boil": _sty((92, 88, 82), (66, 52, 44), 3.0, (62, 60, 58), "DiamondPlate", (84, 80, 76)),
    "auto": _sty((140, 148, 142), TILE_LIGHT, 5.0, (138, 150, 144), "SmoothPlastic", (120, 124, 120), (4.0, (70, 78, 74))),
    "laun": _sty((124, 134, 132), (96, 124, 138), 4.0, (118, 128, 126), "SmoothPlastic", (110, 114, 112), (4.0, (66, 76, 78))),
    "offc": _sty((126, 116, 100), (84, 62, 46), 3.4, (92, 78, 70), "Fabric", (116, 110, 98)),
    "elev": _sty((90, 92, 88), (70, 72, 68), 3.0, (60, 60, 58), "DiamondPlate", (80, 80, 76)),
    "work": _sty((96, 94, 88), (80, 70, 54), 3.0, (70, 68, 64), "Concrete", (86, 84, 80)),
    "recep": _sty((140, 134, 122), (82, 96, 88), 3.6, (150, 146, 138), "Marble", (122, 118, 110), (6.0, (96, 92, 86))),
    "pump": _sty((84, 90, 88), (58, 82, 84), 4.0, (60, 66, 66), "Concrete", (80, 84, 82)),
    "lock": _sty((130, 138, 134), (70, 96, 108), 4.4, (112, 120, 116), "SmoothPlastic", (112, 116, 112), (4.0, (64, 72, 74))),
    "cold": _sty((146, 156, 156), TILE_LIGHT, 5.2, (150, 162, 162), "SmoothPlastic", (126, 134, 134), (4.0, (84, 94, 96))),
    "crem": _sty((108, 90, 80), BRICK, 4.0, (62, 56, 52), "Concrete", (88, 80, 74)),
    "tun": _sty((84, 88, 84), (62, 74, 70), 2.6, (62, 64, 60), "Concrete", (76, 78, 74)),
}

# key: (rect x0, z0, x1, z1), title shown on door signs, style, floor level
SPACES = [
    ("RN", (-62, -40, 62, -28), None, "ring", 0.0), ("RS", (-62, 28, 62, 40), None, "ring", 0.0),
    ("RW", (-62, -28, -50, 28), None, "ring", 0.0), ("RE", (50, -28, 62, 28), None, "ring", 0.0),
    ("COLD", (-50, -28, 0, 28), "МОРГ", "cold", 0.0), ("CREM", (0, -28, 50, 28), "КРЕМАТОРИЙ", "crem", 0.0),
    ("BOIL", (-110, -90, -62, -40), "КОТЕЛЬНАЯ", "boil", 0.0), ("CHAP", (-110, -40, -62, 0), "МОЛЕЛЬНЯ", "chap", 0.0),
    ("ARCH", (-110, 0, -62, 40), "АРХИВ", "arch", 0.0), ("STAIR", (-110, 40, -62, 90), "ЛЕСТНИЦА", "stair", 0.0),
    ("AUTO", (-62, -90, -20, -40), "СЕКЦИОННАЯ", "auto", 0.0), ("LAUN", (-20, -90, 20, -40), "ПРАЧЕЧНАЯ", "laun", 0.0),
    ("OFFC", (20, -90, 62, -40), "КОНТОРА", "offc", 0.0), ("ELEV", (62, -90, 110, -40), "ГРУЗОВОЙ ЛИФТ", "elev", 0.0),
    ("WORK", (62, -40, 110, 0), "МАСТЕРСКАЯ", "work", 0.0), ("RECEP", (62, 0, 110, 40), "ПРИЁМНАЯ", "recep", 0.0),
    ("PUMP", (62, 40, 110, 90), "НАСОСНАЯ", "pump", 0.0), ("LOCK", (-62, 40, -20, 90), "РАЗДЕВАЛКА", "lock", 0.0),
    ("TUN", (-20, 58, 62, 70), "ТОННЕЛЬ", "tun", -1.5), ("SPUR", (14, 40, 26, 58), "ТОННЕЛЬ", "tun", 0.0),
]
RING = ("RN", "RS", "RW", "RE")

# axis ("H": wall along X at z=c, "V": wall along Z at x=c), line, centre along it, space on the - side, on the + side
DOORS = [
    ("H", -40, -86, "BOIL", "CHAP"), ("H", -40, -41, "AUTO", "RN"), ("H", -40, 0, "LAUN", "RN"),
    ("H", -40, 41, "OFFC", "RN"), ("H", -40, 86, "ELEV", "WORK"), ("H", 0, -86, "CHAP", "ARCH"),
    ("H", 0, 86, "WORK", "RECEP"), ("H", 40, -86, "ARCH", "STAIR"), ("H", 40, -41, "RS", "LOCK"),
    ("H", 40, 20, "RS", "SPUR"), ("H", 40, 86, "RECEP", "PUMP"), ("H", 58, 20, "SPUR", "TUN"),
    ("V", -62, -65, "BOIL", "AUTO"), ("V", -62, -14, "CHAP", "RW"), ("V", -62, 14, "ARCH", "RW"),
    ("V", -62, 65, "STAIR", "LOCK"), ("V", -50, -10, "RW", "COLD"), ("V", 0, 10, "COLD", "CREM"),
    ("V", 50, -10, "CREM", "RE"), ("V", -20, -65, "AUTO", "LAUN"), ("V", -20, 64, "LOCK", "TUN"),
    ("V", 20, -65, "LAUN", "OFFC"), ("V", 62, -65, "OFFC", "ELEV"), ("V", 62, -14, "RE", "WORK"),
    ("V", 62, 14, "RE", "RECEP"), ("V", 62, 64, "TUN", "PUMP"),
]


# ------------------------------------------------------------------------------- geometry helpers
def face(dx, dz):
    """rot_y angle whose look vector (-Z) points along (dx, dz)."""
    return math.atan2(-dx, -dz)


def fcf(x, z, dx=0.0, dz=-1.0, y=0.0):
    return CF.new(x, y, z) * CF.rot_y(face(dx, dz))


NORMAL = {"N": (0, 1), "S": (0, -1), "W": (1, 0), "E": (-1, 0)}   # into-room direction when the wall is on that side


def against(side, wall, along, depth=0.0, inset=INSET, y=0.0):
    """Frame (floor level, -Z facing into the room) for a prop of the given depth whose back touches `wall`."""
    nx, nz = NORMAL[side]
    d = inset + depth / 2
    if side in ("N", "S"):
        return fcf(along, wall + nz * d, nx, nz, y)
    return fcf(wall + nx * d, along, nx, nz, y)


def foot(side, wall, along, width, depth, inset=INSET):
    cf = against(side, wall, along, depth, inset)
    hx, hz = (width / 2, depth / 2) if side in ("N", "S") else (depth / 2, width / 2)
    return (cf.p.x - hx, cf.p.z - hz, cf.p.x + hx, cf.p.z + hz)


def on_wall(side, wall, along, y, off=0.06, into="room"):
    """Frame on the wall surface at height y; `into` is the direction -Z looks (room or wall)."""
    nx, nz = NORMAL[side]
    d = 0.5 + off
    fx, fz = (nx, nz) if into == "room" else (-nx, -nz)
    if side in ("N", "S"):
        return fcf(along, wall + nz * d, fx, fz, y)
    return fcf(wall + nx * d, along, fx, fz, y)


def rect_of(cf, w, d, pad=0.0):
    hx, hz = w / 2 + pad, d / 2 + pad
    pts = [cf.point((sx * hx, 0, sz * hz)) for sx in (-1, 1) for sz in (-1, 1)]
    return (min(p.x for p in pts), min(p.z for p in pts), max(p.x for p in pts), max(p.z for p in pts))


def overlap(a, b, eps=0.05):
    return a[0] < b[2] - eps and b[0] < a[2] - eps and a[1] < b[3] - eps and b[1] < a[3] - eps


class Space:
    def __init__(self, key, rect, title, sty, floor_y):
        self.key, self.title, self.sty, self.floor_y = key, title, STY[sty], floor_y
        self.x0, self.z0, self.x1, self.z1 = rect
        self.ring = key in RING

    @property
    def rect(self):
        return (self.x0, self.z0, self.x1, self.z1)

    @property
    def cx(self):
        return (self.x0 + self.x1) / 2

    @property
    def cz(self):
        return (self.z0 + self.z1) / 2

    def inner(self, m=INSET):
        return (self.x0 + m, self.z0 + m, self.x1 - m, self.z1 - m)


# ------------------------------------------------------------------------------------- wall planner
class Walls:
    """Collects wall claims per line, merges shared walls, cuts door gaps and emits Wall/Wainscot parts."""

    def __init__(self):
        self.lines = {}
        self.out = []

    def _line(self, axis, c):
        return self.lines.setdefault((axis, round(c, 3)), {"claims": [], "doors": []})

    def claim(self, axis, c, a, b, side, sty, y0=0.0):
        self._line(axis, c)["claims"].append((min(a, b), max(a, b), side, sty, y0))

    def door(self, axis, c, center, w=DOOR_W):
        self._line(axis, c)["doors"].append((center - w / 2, center + w / 2))

    def emit(self, M):
        sc, st = M.sc, M.st
        for (axis, c), ln in sorted(self.lines.items()):
            doors = ln["doors"]
            edges = {d for pair in doors for d in pair}
            cuts = sorted({v for a, b, *_ in ln["claims"] for v in (a, b)} | edges)
            pieces = []
            for s, e in zip(cuts, cuts[1:]):
                mid = (s + e) / 2
                if any(a < mid < b for a, b in doors):
                    continue
                sty, y0s = {-1: None, 1: None}, {-1: None, 1: None}
                for a, b, side, style, yy in ln["claims"]:
                    if a < mid < b and sty[side] is None:
                        sty[side], y0s[side] = style, yy
                if sty[-1] is None and sty[1] is None:
                    continue
                pieces.append([s, e, sty[-1], sty[1], y0s[-1], y0s[1]])
            merged = []
            for p in pieces:
                if merged and abs(merged[-1][1] - p[0]) < 1e-6 and merged[-1][2:] == p[2:]:
                    merged[-1][1] = p[1]
                else:
                    merged.append(p)
            for s, e, sm, sp, ym, yp in merged:
                ext = lambda v: 0.0 if (axis == "V" or v in edges) else 0.5
                lo, hi = s - ext(s), e + ext(e)
                y0 = min(y for y in (ym, yp) if y is not None)
                a, b = ((lo, c), (hi, c)) if axis == "H" else ((c, lo), (c, hi))
                one = sm or sp
                col, mat = (NEUTRAL_WALL, "Concrete") if (sm and sp) else (one["wall"], one["wmat"])
                P.wall(sc, st, a, b, H - y0, 1.0, col, mat, y0, "Wall")
                self.out.append((axis, c, lo, hi, y0))
                for side, sty, yy in ((-1, sm, ym), (1, sp, yp)):
                    if not sty:
                        continue
                    th, mid, ln_ = sty["th"], (lo + hi) / 2, hi - lo
                    off = side * 0.62
                    cf, size = ((CF.new(mid, yy + th / 2, c + off), (ln_, th, 0.25)) if axis == "H"
                                else (CF.new(c + off, yy + th / 2, mid), (0.25, th, ln_)))
                    sc.part(st, "Wainscot", cf, size, sty["tile"], material="SmoothPlastic")
                    tcf = (CF.new(mid, yy + th + 0.09, c + side * 0.66) if axis == "H" else CF.new(c + side * 0.66, yy + th + 0.09, mid))
                    tsz = (ln_, 0.18, 0.34) if axis == "H" else (0.34, 0.18, ln_)
                    sc.part(st, "Wainscot", tcf, tsz, tuple(min(255, int(v * 1.25) + 8) for v in sty["tile"]), material="SmoothPlastic")


# ------------------------------------------------------------------------------------------ context
class Ctx:
    def __init__(self, sc, mp):
        self.sc, self.mp = sc, mp
        self.st, self.dec, self.li = sc.folder(mp, "Structure"), sc.folder(mp, "Decor"), sc.folder(mp, "Lights")
        self.lk = sc.folder(mp, "Lockers")
        spawns = sc.folder(mp, "Spawns")
        self.fz, self.bz = sc.folder(spawns, "Fuse"), sc.folder(spawns, "Battery")
        self.nodes, self.gens = sc.folder(mp, "AINodes"), sc.folder(mp, "Generators")
        self.walls = Walls()
        self.spaces, self.blocks, self.zones, self.door_list = {}, [], [], []
        self.n_lamp = 0
        self.node_pts, self.pick_pts, self.gen_front = [], [], []
        self.spawn_xz = self.monster_xz = None

    # -- registry ---------------------------------------------------------------------------------
    def block(self, x0, z0, x1, z1, tag=""):
        self.blocks.append((min(x0, x1), min(z0, z1), max(x0, x1), max(z0, z1), tag))

    def block_cf(self, cf, w, d, pad=0.0, tag=""):
        r = rect_of(cf, w, d, pad)
        self.block(*r, tag)
        return r

    def block_foot(self, side, wall, along, width, depth, tag=""):
        r = foot(side, wall, along, width, depth)
        self.block(*r, tag)
        return r

    # -- spaces / doors ----------------------------------------------------------------------------
    def space(self, key, rect, title, sty, floor_y):
        sc = self.sc
        sp = Space(key, rect, title, sty, floor_y)
        self.spaces[key] = sp
        s = sp.sty
        P.slab(sc, self.st, "Floor", sp.x0, sp.z0, sp.x1, sp.z1, floor_y - 0.5, 1.0, s["floor"], s["fmat"])
        P.slab(sc, self.st, "Ceiling", sp.x0, sp.z0, sp.x1, sp.z1, H + 0.5, 1.0, s["ceil"], "Concrete")
        if not sp.ring:
            self.walls.claim("H", sp.z0, sp.x0, sp.x1, +1, s, floor_y)
            self.walls.claim("H", sp.z1, sp.x0, sp.x1, -1, s, floor_y)
            self.walls.claim("V", sp.x0, sp.z0, sp.z1, +1, s, floor_y)
            self.walls.claim("V", sp.x1, sp.z0, sp.z1, -1, s, floor_y)
        if s["grout"]:
            self.grout(sp, *s["grout"])
        return sp

    def ring_walls(self):
        s = STY["ring"]
        for c, a, b, side in ((-40, -62, 62, +1), (40, -62, 62, -1), (-28, -50, 50, -1), (28, -50, 50, +1)):
            self.walls.claim("H", c, a, b, side, s)
        for c, a, b, side in ((-62, -40, 40, +1), (62, -40, 40, -1), (-50, -28, 28, -1), (50, -28, 28, +1)):
            self.walls.claim("V", c, a, b, side, s)

    def grout(self, sp, step, color):
        sc = self.sc
        x0, z0, x1, z1 = sp.rect
        y = sp.floor_y + 0.02
        z = z0 + step
        while z < z1 - 0.4:
            sc.part(self.dec, "Grout", CF.new((x0 + x1) / 2, y, z), (x1 - x0 - 0.2, 0.04, 0.1), color, collide=False, cast_shadow=False)
            z += step
        x = x0 + step
        while x < x1 - 0.4:
            sc.part(self.dec, "Grout", CF.new(x, y, (z0 + z1) / 2), (0.1, 0.04, z1 - z0 - 0.2), color, collide=False, cast_shadow=False)
            x += step

    def door(self, axis, c, center, a_key, b_key, leaves=False, rot=0.0):
        sc = self.sc
        self.walls.door(axis, c, center)
        cf = CF.new(center, 0, c) if axis == "H" else CF.new(c, 0, center) * CF.rot_y(HALF_PI)
        P.door_frame(sc, self.st, cf)
        sc.part(self.st, "Frame", at(cf, 0, 0.04, 0), (DOOR_W, 0.08, 1.4), STEEL, material="DiamondPlate", collide=False)
        if leaves:
            a1 = 0.25 + sc.rng.random() * 0.7
            P.door(sc, self.dec, at(cf, -2.2, 0, 0), open_angle=a1)
            P.door(sc, self.dec, cf * CF.new(2.2, 0, 0) * CF.rot_y(PI), open_angle=-(0.2 + sc.rng.random() * 0.8))
        if axis == "H":
            self.zones.append((center - 4.4, c - 6.5, center + 4.4, c + 6.5, "door"))
        else:
            self.zones.append((c - 6.5, center - 4.4, c + 6.5, center + 4.4, "door"))
        self.door_list.append((axis, c, center, a_key, b_key))
        self.node_pts.append((cf.p.x, cf.p.z))
        # hanging sign over the opening for each room on either side
        for side, dest in ((-1, b_key), (1, a_key)):
            title = self.spaces[dest].title
            if title and dest not in RING:
                self.hang_sign(axis, c, center, title, side)

    def hang_sign(self, axis, c, center, text, toward, y=9.3):
        sc = self.sc
        off = 0.95 * toward
        cf = fcf(center, c + off, 0, toward, y) if axis == "H" else fcf(c + off, center, toward, 0, y)
        P.room_sign(sc, self.dec, cf, text)
        for sx in (-2.5, 2.5):
            sc.cyl(self.dec, "Part", at(cf, sx, 0.5, 0).p, at(cf, sx, H - y, 0).p, 0.05, (58, 58, 56), material="Metal", collide=False)

    # -- lights --------------------------------------------------------------------------------------
    def lamp(self, x, z, kind=None, rot=0.0, y=10.7):
        self.n_lamp += 1
        if kind is None:
            kind = "FlickerLamp" if self.n_lamp % 5 in (2, 4) else "Lamp"
        return P.ceiling_lamp(self.sc, self.li, (x, y, z), kind=kind, rot=rot)

    def emerg(self, side, wall, along, y=9.2):
        P.emergency_light(self.sc, self.li, on_wall(side, wall, along, y, off=0.3))
        self.sc.part(self.dec, "Part", on_wall(side, wall, along, y, off=0.1), (1.5, 0.9, 0.2), (34, 32, 30), material="Metal", collide=False)

    # -- generic decor ---------------------------------------------------------------------------------
    def puddle(self, x, z, w=3.0, d=2.0, y=0.0):
        cf = CF.new(x, y + 0.03, z) * CF.rot_y(self.sc.rng.random() * 6.28)
        self.sc.ellipsoid(self.dec, "Part", cf, (w, 0.05, d), (16, 22, 24), material="Glass", transparency=0.4, reflectance=0.25, collide=False)

    def drain(self, x, z, y=0.0):
        sc = self.sc
        sc.cyl(self.dec, "Part", (x, y + 0.01, z), (x, y + 0.07, z), 0.95, (22, 22, 22), material="Metal", collide=False)
        for k in range(3):
            sc.part(self.dec, "Part", CF.new(x, y + 0.09, z) * CF.rot_y(k * PI / 3), (1.7, 0.05, 0.12), (66, 66, 64), material="Metal", collide=False)

    def anchor(self, x, y, z, size=(1, 1, 1)):
        return self.sc.part(self.dec, "Part", CF.new(x, y, z), size, (0, 0, 0), transparency=1, collide=False, can_query=False, cast_shadow=False)

    def drip(self, x, y, z, rate=1.2):
        a = self.anchor(x, y, z, (0.3, 0.3, 0.3))
        self.sc.particles(a, "Drip", "rbxasset://textures/particles/sparkles_main.dds", [(0, (170, 200, 210)), (1, (170, 200, 210))],
                          [(0, 0.2), (1, 0.14)], [(0, 0.15), (1, 0.7)], (0.6, 0.9), rate, (0, 0), spread=(0, 0),
                          light_emission=0.1, acceleration=(0, -48, 0), direction="Bottom")

    def leak(self, x, z, y=10.4, w=2.4):
        self.drip(x, y, z)
        self.puddle(x, z, w, w * 0.7)

    def fog(self, x, z, w=16, d=16, y=0.9, rate=2.5, color=(196, 210, 220)):
        a = self.anchor(x, y, z, (w, 0.6, d))
        self.sc.particles(a, "Fog", "rbxasset://textures/particles/smoke_main.dds", [(0, color), (1, color)], [(0, 7), (1, 14)],
                          [(0, 1), (0.25, 0.86), (1, 1)], (6, 9), rate, (0.2, 0.7), spread=(180, 180), acceleration=(0, 0.1, 0))

    def steam(self, x, y, z, rate=7):
        a = self.anchor(x, y, z, (0.4, 0.4, 0.4))
        self.sc.smoke(a, color=(214, 214, 210), rate=rate, size=(1.2, 5), lifetime=(1.6, 2.8), speed=(3, 5), transparency=0.5)

    def cable(self, a, b, sag=1.2, r=0.08, n=5, color=(20, 20, 20)):
        a, b = V3(*a), V3(*b)
        prev = a
        for i in range(1, n + 1):
            t = i / n
            p = a.lerp(b, t) - V3(0, 4 * sag * t * (1 - t), 0)
            self.sc.cyl(self.dec, "Part", prev, p, r, color, collide=False)
            prev = p

    def pipe(self, pts, r=0.35, color=P.RUST, mat="CorrodedMetal"):
        P.pipe_run(self.sc, self.dec, pts, r, color, mat)

    def valve(self, x, y, z, ax="z", r=0.7):
        """Hand wheel on a stem; ax is the stem direction (x or z)."""
        sc = self.sc
        d = (1, 0, 0) if ax == "x" else (0, 0, 1)
        a, b = (x - d[0] * 0.5, y, z - d[2] * 0.5), (x + d[0] * 0.5, y, z + d[2] * 0.5)
        sc.cyl(self.dec, "Part", a, b, 0.12, (60, 60, 58), material="Metal", collide=False)
        cf = CF.new(x, y, z) * (CF.rot_y(HALF_PI) if ax == "x" else CF.new())
        sc.cyl(self.dec, "Part", (x + d[0] * 0.55, y, z + d[2] * 0.55), (x + d[0] * 0.67, y, z + d[2] * 0.67), r, (150, 40, 34), material="Metal", collide=False)
        for k in range(2):
            sc.part(self.dec, "Part", cf * CF.new(0, 0, 0.6) * CF.rot_z(k * HALF_PI), (r * 2, 0.1, 0.1), (110, 30, 26), material="Metal", collide=False)

    def gauge(self, cf, r=0.6):
        sc = self.sc
        sc.cyl(self.dec, "Part", at(cf, 0, 0, 0).p, at(cf, 0, 0, -0.3).p, r, (30, 30, 30), material="Metal", collide=False)
        sc.cyl(self.dec, "Part", at(cf, 0, 0, -0.28).p, at(cf, 0, 0, -0.34).p, r * 0.82, (222, 218, 205), material="SmoothPlastic", collide=False)
        sc.part(self.dec, "Part", at(cf, 0, 0.12, -0.38, rz=sc.rng.random() * 2 - 1), (0.06, r * 0.7, 0.04), (170, 20, 20), material="SmoothPlastic", collide=False)

    def claws(self, cf, n=4, length=3.2):
        sc = self.sc
        for i in range(n):
            sc.part(self.dec, "Part", at(cf, (i - (n - 1) / 2) * 0.5, sc.jitter(0.2), 0.03, rz=0.22 + sc.jitter(0.06)),
                    (0.1, length + sc.jitter(0.5), 0.05), BLOOD_DARK if i % 2 else (28, 10, 10), material="Granite", collide=False)

    def writing(self, side, wall, along, y, text, size=(8, 2.2, 0.08)):
        return P.writing(self.sc, self.dec, on_wall(side, wall, along, y, off=0.07), text, size=size)

    def poster(self, side, wall, along, y, text, size=(3.0, 2.0)):
        return P.poster(self.sc, self.dec, on_wall(side, wall, along, y, off=0.06), text, size=size)

    def smear(self, side, wall, along, y, length=3.0):
        P.blood_smear(self.sc, self.dec, on_wall(side, wall, along, y, off=-0.02, into="wall"), length)

    def stain(self, side, wall, along, y, w=3.0, h=5.0):
        cf = on_wall(side, wall, along, y, off=0.03)
        self.sc.ellipsoid(self.dec, "Part", cf, (w, h, 0.05), (52, 46, 38), material="Granite", transparency=0.55, collide=False)

    def trail(self, pts, step=2.3, color=BLOOD_DARK):
        """Blood footprints along a polyline."""
        sc = self.sc
        pts = [V3(p[0], 0.03, p[1]) for p in pts]
        k = 0
        for a, b in zip(pts, pts[1:]):
            d = b - a
            n = max(1, int(d.mag / step))
            ang = math.atan2(d.x, d.z)
            for i in range(n):
                p = a + d * (i / n)
                side = 0.45 if k % 2 else -0.45
                cf = CF.new(p.x + math.cos(ang) * side, 0.03, p.z - math.sin(ang) * side) * CF.rot_y(ang)
                sc.ellipsoid(self.dec, "Part", cf, (0.7, 0.04, 1.3), color, material="Granite", collide=False)
                k += 1

    # -- hide spots -----------------------------------------------------------------------------------
    def locker(self, side, wall, along):
        P.locker(self.sc, self.lk, against(side, wall, along, 2.6))
        self.block_foot(side, wall, along, 3.0, 2.6, "locker")

    # -- nav ---------------------------------------------------------------------------------------------
    def free(self, x, z, margin=NAV_R, zones=True):
        for b in self.blocks:
            if b[0] - margin < x < b[2] + margin and b[1] - margin < z < b[3] + margin:
                return False
        if zones:
            for zn in self.zones:
                if zn[0] < x < zn[2] and zn[1] < z < zn[3]:
                    return False
        return True

    def in_space(self, x, z, m=1.0):
        for sp in self.spaces.values():
            if sp.x0 + m < x < sp.x1 - m and sp.z0 + m < z < sp.z1 - m:
                return sp
        return None


# @@PROPS@@

# @@ROOMS@@


# ------------------------------------------------------------------------------------- generators
def place_generator(M, side, wall, along):
    cf = against(side, wall, along, 6.0)
    P.generator(M.sc, M.gens, cf)
    M.block_foot(side, wall, along, 10.0, 6.0, "gen")
    nx, nz = NORMAL[side]
    ctr = (cf.p.x + nx * 7.5, cf.p.z + nz * 7.5)
    hx, hz = (5.5, 4.0) if side in ("N", "S") else (4.0, 5.5)
    M.zones.append((ctr[0] - hx, ctr[1] - hz, ctr[0] + hx, ctr[1] + hz, "gen"))
    M.gen_front.append(ctr)


# ----------------------------------------------------------------------------------- nodes / pickups
def make_nodes(M):
    sc = M.sc
    grid = []
    for key, sp in M.spaces.items():
        if sp.ring:
            continue
        if key == "TUN":
            x0, z0, x1, z1 = sp.inner(3.2)
            n = int((x1 - x0) // 11) + 1
            grid += [(x0 + i * (x1 - x0) / max(1, n - 1), sp.cz) for i in range(n)]
            continue
        if key == "SPUR":
            grid += [(sp.cx, z) for z in (45.0, 52.0)]
            continue
        x0, z0, x1, z1 = sp.inner(4.2)
        nx = max(1, math.ceil((x1 - x0) / 11.5)) + 1
        nz = max(1, math.ceil((z1 - z0) / 11.5)) + 1
        for i in range(nx):
            for j in range(nz):
                grid.append((x0 + (x1 - x0) * i / (nx - 1), z0 + (z1 - z0) * j / (nz - 1)))
    loop = [(-56, -34), (56, -34), (56, 34), (-56, 34), (-56, -34)]
    for (ax, az), (bx, bz) in zip(loop, loop[1:]):
        n = int(max(abs(bx - ax), abs(bz - az)) // 11) + 1
        grid += [(ax + (bx - ax) * i / n, az + (bz - az) * i / n) for i in range(n)]
    out = list(M.node_pts)          # door centres first
    for x, z in grid:
        if not M.free(x, z, NAV_R + 0.3, zones=False) or M.in_space(x, z, 0.5) is None:
            continue
        if any((x - ox) ** 2 + (z - oz) ** 2 < 40 for ox, oz in out):
            continue
        out.append((x, z))
    M.node_pts = out
    for x, z in out:
        P.node(sc, M.nodes, (x, 3, z))


def make_pickups(M, plan):
    sc = M.sc
    for key, nf, nb in plan:
        sp = M.spaces[key]
        x0, z0, x1, z1 = sp.inner(4.4)
        for count, folder in ((nf, M.fz), (nb, M.bz)):
            for _ in range(count):
                for _try in range(300):
                    x, z = x0 + sc.rng.random() * (x1 - x0), z0 + sc.rng.random() * (z1 - z0)
                    if M.free(x, z, 2.0) and all((x - ox) ** 2 + (z - oz) ** 2 > 100 for ox, oz in M.pick_pts):
                        M.pick_pts.append((x, z))
                        P.spawn_point(sc, folder, (x, sp.floor_y + 0.5, z))
                        break


# --------------------------------------------------------------------------------------- self check
def selfcheck(M):
    """Layout invariants: no prop in a doorway / in front of a generator, every node reachable by the monster."""
    problems = []
    for b in M.blocks:
        for z in M.zones:
            if overlap(b, z):
                problems.append("block %s overlaps zone %s at (%.0f,%.0f)" % (b[4], z[4], b[0], b[1]))
    x0, z0, x1, z1, res = -114.0, -94.0, 114.0, 94.0, 1.0
    w, h = int((x1 - x0) / res), int((z1 - z0) / res)
    free = bytearray(w * h)

    def cells(r, grow):
        return (max(0, int((r[0] - grow - x0) / res)), min(w - 1, int((r[2] + grow - x0) / res)),
                max(0, int((r[1] - grow - z0) / res)), min(h - 1, int((r[3] + grow - z0) / res)))

    for sp in M.spaces.values():
        ix0, ix1, iz0, iz1 = cells(sp.rect, -0.4)
        for iz in range(iz0, iz1 + 1):
            for ix in range(ix0, ix1 + 1):
                free[iz * w + ix] = 1
    for axis, c, lo, hi, _ in M.walls.out:
        r = (lo, c - 0.75, hi, c + 0.75) if axis == "H" else (c - 0.75, lo, c + 0.75, hi)
        ix0, ix1, iz0, iz1 = cells(r, NAV_R)
        for iz in range(iz0, iz1 + 1):
            for ix in range(ix0, ix1 + 1):
                free[iz * w + ix] = 0
    for b in M.blocks:
        ix0, ix1, iz0, iz1 = cells(b, NAV_R)
        for iz in range(iz0, iz1 + 1):
            for ix in range(ix0, ix1 + 1):
                free[iz * w + ix] = 0
    sx, sz = M.spawn_xz
    start = (int((sx - x0) / res), int((sz - z0) / res))
    dist = {start: 0.0}
    pq = [(0.0, start)]
    while pq:
        d, (ix, iz) = heapq.heappop(pq)
        if d > dist.get((ix, iz), 1e9):
            continue
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                if not (dx or dz):
                    continue
                nx_, nz_ = ix + dx, iz + dz
                if 0 <= nx_ < w and 0 <= nz_ < h and free[nz_ * w + nx_]:
                    if dx and dz and not (free[iz * w + nx_] and free[nz_ * w + ix]):
                        continue
                    nd = d + (1.4142 if dx and dz else 1.0) * res
                    if nd < dist.get((nx_, nz_), 1e9):
                        dist[(nx_, nz_)] = nd
                        heapq.heappush(pq, (nd, (nx_, nz_)))

    def reach(x, z):
        return dist.get((int((x - x0) / res), int((z - z0) / res)))

    M.grid = (x0, z0, w, h, free, dist)

    lost = [(round(x), round(z)) for x, z in M.node_pts if reach(x, z) is None]
    if lost:
        problems.append("unreachable nodes: %s" % lost[:12])
    lostp = [(round(x), round(z)) for x, z in M.pick_pts if reach(x, z) is None]
    if lostp:
        problems.append("unreachable pickups: %s" % lostp[:12])
    for gx, gz in M.gen_front:
        if reach(gx, gz) is None:
            problems.append("generator front unreachable at (%.0f,%.0f)" % (gx, gz))
    mz = reach(*M.monster_xz)
    if mz is None:
        problems.append("monster spawn unreachable")
    elif mz < 125:
        problems.append("monster spawn only %.0f studs from the spawn" % mz)
    M.stats = {"monster_walk": mz, "nodes": len(M.node_pts)}
    if problems:
        raise AssertionError("morgue layout problems:\n  " + "\n  ".join(problems))


# -------------------------------------------------------------------------------------------- build
def build(sc, parent):
    mp = sc.folder(parent, "Morgue")
    M = Ctx(sc, mp)
    for key, rect, title, sty, fy in SPACES:
        M.space(key, rect, title, sty, fy)
    M.ring_walls()
    for i, (axis, c, center, a, b) in enumerate(DOORS):
        M.door(axis, c, center, a, b, leaves=(i % 2 == 0))
    build_rooms(M)
    M.walls.emit(M)
    make_nodes(M)
    make_pickups(M, PICKUPS)
    selfcheck(M)
    return mp


PICKUPS = [("STAIR", 1, 1), ("ARCH", 2, 1), ("CHAP", 1, 1), ("BOIL", 1, 2), ("AUTO", 2, 1), ("LAUN", 1, 2),
           ("OFFC", 2, 1), ("ELEV", 0, 1), ("WORK", 1, 1), ("RECEP", 1, 2), ("PUMP", 1, 1), ("LOCK", 2, 2),
           ("COLD", 1, 1), ("CREM", 1, 1), ("RN", 0, 1), ("RS", 0, 1), ("RW", 0, 1), ("RE", 0, 1)]


def build_rooms(M):
    sc = M.sc
    sx, sz = -84.0, 70.0
    sc.spawn_location(M.mp, CF.new(sx, -0.45, sz))
    M.spawn_xz = (sx, sz)
    P.marker(sc, M.mp, "MonsterSpawn", (-8.0, 2.0, -6.0))
    M.monster_xz = (-8.0, -6.0)
