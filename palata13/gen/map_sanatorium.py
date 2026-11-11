"""САНАТОРИЙ «СОСНЫ» — abandoned children's sanatorium in a foggy pine forest.
Story: the children's ward closed after an "accident"; at night the chapel bell rings with no ringer.
The perimeter fence is electrified only when there is power — four generators open the main (south) gate.
"""
import math
from buildkit.cframe import CF, V3
from gen import props as P

CEILING_Y = 11.5
PREVIEW_SCALE = 2
PI = math.pi

H = 12.0  # wall height
DOOR = 8.0
WALL_C = (138, 128, 112)
WALL_IN = (168, 160, 140)
TRIM = (96, 70, 52)
FLOOR_C = (110, 84, 60)
GRASS = (34, 44, 30)

# rect = (x0, z0, x1, z1); doors = list of (side, offset_along_side); side in N,S,E,W
BUILDINGS = {
    "main": ((-60, 40, 60, 90), [("S", 0.0)]),
    "chapel": ((-124, 60, -92, 106), [("S", 0.0)]),
    "boiler": ((90, 50, 124, 80), [("W", 0.0)]),
    "bath": ((-130, -40, -90, -10), [("E", 0.0)]),
    "garage": ((90, -52, 122, -24), [("W", 0.0)]),
    "pump": ((-22, -102, 6, -80), [("N", 0.0)]),
}


def wall_gaps(sc, st, a, b, gaps, color=WALL_C, material="Brick", wainscot=None):
    """Wall a->b (XZ) with door gaps centred at distances `gaps` from a; headers above each gap."""
    a, b = V3(a[0], 0, a[1]), V3(b[0], 0, b[1])
    d = b - a
    length = d.mag
    u = d.unit
    cuts = sorted(gaps)
    pos = 0.0
    for g in cuts:
        s, e = g - DOOR / 2, g + DOOR / 2
        if s - pos > 0.05:
            p0, p1 = a + u * pos, a + u * s
            P.wall(sc, st, (p0.x, p0.z), (p1.x, p1.z), H, color=color, material=material, wainscot=wainscot)
        p0, p1 = a + u * s, a + u * e
        P.wall(sc, st, (p0.x, p0.z), (p1.x, p1.z), 1.0, color=color, material=material, y0=H - 1.0, name="Header")
        mid = a + u * g
        rot = math.atan2(-u.z, u.x)
        P.door_frame(sc, st, CF.new(mid.x, 0, mid.z) * CF.rot_y(rot), width=DOOR, height=H - 1.2, color=TRIM)
        pos = e
    if length - pos > 0.05:
        p0 = a + u * pos
        P.wall(sc, st, (p0.x, p0.z), (b.x, b.z), H, color=color, material=material, wainscot=wainscot)


def building(sc, st, dec, rect, doors, roof=(70, 40, 36)):
    x0, z0, x1, z1 = rect
    P.slab(sc, st, "Floor", x0, z0, x1, z1, -0.45, 1, FLOOR_C, "WoodPlanks")
    P.slab(sc, st, "Ceiling", x0, z0, x1, z1, H + 0.5, 1, (120, 116, 104), "Concrete")
    # pitched roof: two sloped slabs over the long axis
    w, d = x1 - x0, z1 - z0
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    if w >= d:
        for s in (-1, 1):
            cf = CF.new(cx, H + 3.0, cz + s * d / 4) * CF.rot_x(s * 0.42)
            sc.part(st, "Roof", cf, (w + 2, 0.6, d / 2 / math.cos(0.42) + 1.2), roof, material="Slate")
    else:
        for s in (-1, 1):
            cf = CF.new(cx + s * w / 4, H + 3.0, cz) * CF.rot_z(-s * 0.42)
            sc.part(st, "Roof", cf, (w / 2 / math.cos(0.42) + 1.2, 0.6, d + 2), roof, material="Slate")
    gaps = {"N": [], "S": [], "E": [], "W": []}
    for side, off in doors:
        gaps[side].append(off)
    wa = (WAINSCOT_IN, 3.2)
    wall_gaps(sc, st, (x0, z0), (x1, z0), [w / 2 + g for g in gaps["S"]], wainscot=wa)
    wall_gaps(sc, st, (x0, z1), (x1, z1), [w / 2 + g for g in gaps["N"]], wainscot=wa)
    wall_gaps(sc, st, (x0, z0), (x0, z1), [d / 2 + g for g in gaps["W"]], wainscot=wa)
    wall_gaps(sc, st, (x1, z0), (x1, z1), [d / 2 + g for g in gaps["E"]], wainscot=wa)
    # fake windows on the outside: glass + frame + some boarded up
    for side in "NSEW":
        if side in "NS":
            z = z1 + 0.55 if side == "N" else z0 - 0.55
            n = int(w // 12)
            spots = [(x0 + (i + 0.5) * w / n, z) for i in range(n)]
        else:
            x = x1 + 0.55 if side == "E" else x0 - 0.55
            n = int(d // 12)
            spots = [(x, z0 + (i + 0.5) * d / n) for i in range(n)]
        for (wx, wz) in spots:
            near_door = any((side == s2) and abs(((wx - cx) if side in "NS" else (wz - cz)) - off) < 6 for s2, off in doors)
            if near_door:
                continue
            rot = 0 if side in "NS" else PI / 2
            cf = CF.new(wx, 6.5, wz) * CF.rot_y(rot)
            sc.part(dec, "Window", cf, (4.2, 5.2, 0.12), (40, 52, 58), material="Glass", transparency=0.35, collide=False)
            sc.part(dec, "WinFrame", cf * CF.new(0, 2.7, 0), (4.8, 0.35, 0.3), TRIM, material="Wood", collide=False)
            sc.part(dec, "WinFrame", cf * CF.new(0, -2.7, 0), (4.8, 0.35, 0.3), TRIM, material="Wood", collide=False)
            sc.part(dec, "WinFrame", cf * CF.new(0, 0, 0), (0.25, 5.2, 0.3), TRIM, material="Wood", collide=False)
            if sc.chance(0.45):
                for k in range(3):
                    sc.part(dec, "Board", cf * CF.new(0, -1.6 + k * 1.6, 0.2) * CF.rot_z(sc.jitter(0.25)), (5.0, 0.7, 0.15),
                            sc.vary(P.WOOD, 10), material="WoodPlanks", collide=False)


WAINSCOT_IN = (72, 58, 46)


def ceiling_lamps(sc, li, rect, step=14, flicker=0.4):
    x0, z0, x1, z1 = rect
    nx = max(1, int((x1 - x0) // step))
    nz = max(1, int((z1 - z0) // step))
    for i in range(nx):
        for j in range(nz):
            x = x0 + (i + 0.5) * (x1 - x0) / nx
            z = z0 + (j + 0.5) * (z1 - z0) / nz
            P.ceiling_lamp(sc, li, (x, H - 0.3, z), kind="FlickerLamp" if sc.chance(flicker) else "Lamp", color=P.WARM, range_=20)


def interior_nodes(sc, nodes, rect, step=10, margin=4):
    x0, z0, x1, z1 = rect
    x = x0 + margin
    while x <= x1 - margin:
        z = z0 + margin
        while z <= z1 - margin:
            P.node(sc, nodes, (x, 3, z))
            z += step
        x += step


def rand_in(sc, rect, margin=4):
    x0, z0, x1, z1 = rect
    return (x0 + margin + sc.rng.random() * (x1 - x0 - 2 * margin), 0.5, z0 + margin + sc.rng.random() * (z1 - z0 - 2 * margin))


def build(sc, parent):
    mp = sc.folder(parent, "Sanatorium")
    st = sc.folder(mp, "Structure")
    dec = sc.folder(mp, "Decor")
    li = sc.folder(mp, "Lights")
    lk = sc.folder(mp, "Lockers")
    sp = sc.folder(mp, "Spawns")
    fuse = sc.folder(sp, "Fuse")
    bat = sc.folder(sp, "Battery")
    nodes = sc.folder(mp, "AINodes")
    gens = sc.folder(mp, "Generators")

    P.slab(sc, st, "Ground", -175, -165, 175, 150, -0.5, 1, GRASS, "Grass")
    # leaf litter patches (noisy ground, see the warning on the wall)
    for _ in range(70):
        cf = CF.new(sc.jitter(145), 0.04, sc.jitter(128)) * CF.rot_y(sc.rng.random() * 6.28)
        p = sc.part(dec, "Part", cf, (4 + sc.rng.random() * 8, 0.06, 3 + sc.rng.random() * 6), sc.vary((70, 52, 30), 12), material="Grass", collide=False)
        sc.mesh(p, "Sphere", (1, 0.05, 1))

    # buildings -----------------------------------------------------------------
    rooms = []
    for name, (rect, doors) in BUILDINGS.items():
        building(sc, st, dec, rect, doors, roof=(52, 56, 60) if name == "chapel" else (70, 40, 36))
    # main building partitions: reception (-20..20) + 4 wing rooms
    for x in (-20, 20):
        wall_gaps(sc, st, (x, 40), (x, 90), [12, 38], color=WALL_IN, material="Plaster" if False else "Concrete", wainscot=(WAINSCOT_IN, 3.2))
    for x0, x1 in ((-60, -20), (20, 60)):
        P.wall(sc, st, (x0, 65), (x1, 65), H, color=WALL_IN, material="Concrete", wainscot=(WAINSCOT_IN, 3.2))
    reception = (-20, 40, 20, 90)
    bed_w, bed_n = (-60, 40, -20, 65), (-60, 65, -20, 90)
    dining, play = (20, 40, 60, 65), (20, 65, 60, 90)
    chapel = BUILDINGS["chapel"][0]
    boiler = BUILDINGS["boiler"][0]
    bath = BUILDINGS["bath"][0]
    garage = BUILDINGS["garage"][0]
    pump = BUILDINGS["pump"][0]
    rooms = [reception, bed_w, bed_n, dining, play, chapel, boiler, bath, garage, pump]
    for r in rooms:
        ceiling_lamps(sc, li, r, step=14, flicker=0.5 if r in (chapel, bath, pump) else 0.35)
        interior_nodes(sc, nodes, r)
    for r in rooms:
        P.emergency_light(sc, li, CF.new((r[0] + r[2]) / 2, H - 1.5, r[3] - 0.8))

    # reception: spawn, desk, benches, big sign
    sc.spawn_location(mp, CF.new(0, -0.45, 52), size=(10, 1, 10))
    P.desk(sc, dec, CF.new(-8, 0, 82) * CF.rot_y(PI), w=8, d=3)
    P.cabinet(sc, dec, CF.new(14, 0, 88.6) * CF.rot_y(0), open_door=True)
    P.room_sign(sc, dec, CF.new(0, 10.4, 89.4) * CF.rot_y(PI), "САНАТОРИЙ «СОСНЫ»", style="big", size=(18, 2.2, 0.1))
    for z in (60, 70):
        for sx in (-1, 1):
            sc.part(dec, "Part", CF.new(sx * 14, 1.6, z), (2.0, 0.3, 7), P.WOOD, material="Wood")
            sc.part(dec, "Part", CF.new(sx * 14 + sx * 0.9, 2.8, z), (0.3, 2.4, 7), P.WOOD, material="Wood")
            for k in (-3, 3):
                sc.part(dec, "Part", CF.new(sx * 14, 0.75, z + k), (1.8, 1.5, 0.3), P.WOOD_DARK, material="Wood", collide=False)
    P.writing(sc, dec, CF.new(19.4, 6.5, 55) * CF.rot_y(PI / 2), "ДЕТИ НЕ УШЛИ", size=(12, 2.6, 0.08), style="blood")
    P.papers(sc, dec, (0, 0, 75), n=12, radius=6)
    P.wheelchair(sc, dec, CF.new(-12, 0, 48) * CF.rot_y(0.6))
    P.blood_pool(sc, dec, (6, 0, 66), radius=1.5)

    # bedrooms: rows of small beds, toys, drawings
    for r in (bed_w, bed_n):
        x0, z0, x1, z1 = r
        for i in range(4):
            bx = x0 + 5 + i * 8.5
            P.bed(sc, dec, CF.new(bx, 0, z1 - 5.5) * CF.rot_y(0), bloody=sc.chance(0.3))
            for _ in range(2):
                tx, _, tz = rand_in(sc, r, 6)
                sc.ball(dec, "Part", (tx, 0.6, tz), 1.1, sc.pick([(180, 40, 40), (40, 90, 170), (220, 190, 60)]), material="Plastic", collide=False)
            sc.part(dec, "Part", CF.new(bx + 2, 0.7, z1 - 10) * CF.rot_y(sc.jitter(0.6)), (1.2, 1.2, 1.2), sc.vary((170, 130, 80), 30), material="WoodPlanks", collide=False)
        for i, t in enumerate(["МАМА", "ОНО ПОД КРОВАТЬЮ", "НЕ ЗАСЫПАЙ", "ПАЛАТА 13"]):
            P.poster(sc, dec, CF.new(x0 + 6 + i * 9, 7, z0 + 0.65) * CF.rot_y(PI), t, size=(3.2, 2.4))
        P.wardrobe(sc, lk, CF.new(x0 + 2.2, 0, (z0 + z1) / 2) * CF.rot_y(-PI / 2))
    P.writing(sc, dec, CF.new(-40, 6, 89.4) * CF.rot_y(PI), "НЕ БЕГИ ПО ЛИСТЬЯМ", size=(14, 2.4, 0.08))

    # dining hall
    for k in range(2):
        z = 49 + k * 9
        sc.part(dec, "Part", CF.new(40, 2.5, z), (26, 0.3, 3), P.WOOD, material="Wood")
        for sx in (-12, 0, 12):
            sc.part(dec, "Part", CF.new(40 + sx, 1.25, z), (0.4, 2.5, 2.4), P.WOOD_DARK, material="Wood")
        for i in range(6):
            P.chair(sc, dec, CF.new(30 + i * 4, 0, z + 2.6) * CF.rot_y(PI + sc.jitter(0.4)), fallen=sc.chance(0.2))
            if sc.chance(0.6):
                sc.part(dec, "Part", CF.new(30 + i * 4, 2.75, z + 0.5) * CF.rot_z(PI / 2), (0.2, 1.2, 1.2), (220, 220, 210), material="SmoothPlastic", shape="Cylinder", collide=False)
    P.wardrobe(sc, lk, CF.new(58.2, 0, 52) * CF.rot_y(PI / 2))
    # playroom: rocking horse, crayon wall, blocks
    hx, hz = 40, 80
    sc.part(dec, "Part", CF.new(hx, 2.4, hz), (1.4, 1.6, 4.0), (150, 60, 40), material="Wood")
    sc.part(dec, "Part", CF.new(hx, 3.8, hz - 2.2) * CF.rot_x(0.4), (1.0, 2.0, 1.0), (150, 60, 40), material="Wood")
    sc.part(dec, "Part", CF.new(hx, 0.5, hz), (2.4, 0.4, 6.0), (90, 50, 30), material="Wood")
    for i in range(12):
        sc.part(dec, "Part", CF.new(28 + sc.rng.random() * 24, 0.5, 70 + sc.rng.random() * 16) * CF.rot_y(sc.rng.random() * 3), (1, 1, 1),
                sc.pick([(200, 40, 40), (40, 120, 200), (230, 200, 60), (60, 170, 80)]), material="Plastic", collide=False)
    for i in range(9):
        sc.part(dec, "Crayon", CF.new(59.4, 2 + sc.rng.random() * 4, 68 + i * 2.2) * CF.rot_y(PI / 2) * CF.rot_z(sc.jitter(0.8)),
                (1.8, 0.25, 0.05), sc.pick([(200, 30, 30), (30, 30, 30), (40, 90, 200)]), material="SmoothPlastic", collide=False)
    P.writing(sc, dec, CF.new(40, 6.5, 89.4) * CF.rot_y(PI), "ИГРАЙ С НАМИ", size=(12, 2.4, 0.08), style="blood")
    P.wardrobe(sc, lk, CF.new(58.2, 0, 84) * CF.rot_y(PI / 2))

    # chapel: pews, altar, candles, bell tower; MonsterSpawn
    cx0, cz0, cx1, cz1 = chapel
    for row in range(6):
        z = cz0 + 8 + row * 5
        for sx in (-1, 1):
            x = (cx0 + cx1) / 2 + sx * 6
            sc.part(dec, "Part", CF.new(x, 1.6, z), (8, 0.35, 1.6), P.WOOD_DARK, material="Wood")
            sc.part(dec, "Part", CF.new(x, 2.9, z + 0.75), (8, 2.6, 0.3), P.WOOD_DARK, material="Wood")
    ax = (cx0 + cx1) / 2
    sc.part(dec, "Part", CF.new(ax, 0.6, cz1 - 6), (14, 1.2, 8), (90, 80, 70), material="Marble")
    sc.part(dec, "Part", CF.new(ax, 2.6, cz1 - 6), (6, 2.8, 2.6), (180, 172, 150), material="Marble")
    sc.part(dec, "Part", CF.new(ax, 4.1, cz1 - 6), (6.4, 0.2, 3.0), (130, 20, 20), material="Fabric", collide=False)
    sc.part(dec, "Part", CF.new(ax + 3, 0.6, cz1 - 12) * CF.rot_z(PI / 2) * CF.rot_x(0.3), (9, 0.8, 0.8), P.WOOD_DARK, material="Wood", collide=False)  # toppled cross
    sc.part(dec, "Part", CF.new(ax + 1.5, 0.6, cz1 - 12) * CF.rot_x(0.3), (0.8, 0.8, 5), P.WOOD_DARK, material="Wood", collide=False)
    for i in range(8):
        P.candle(sc, dec, li, (ax - 2.6 + i * 0.75, 4.2, cz1 - 6 + sc.jitter(0.6)))
    P.writing(sc, dec, CF.new(ax, 8, cz1 - 0.6) * CF.rot_y(PI), "КОЛОКОЛ ЗВОНИТ ПО ТЕБЕ", size=(16, 2.4, 0.08))
    P.marker(sc, mp, "MonsterSpawn", (ax, 2, cz1 - 14))
    # bell tower on top of the north end
    sc.part(st, "Wall", CF.new(ax, H + 10, cz1 - 6), (12, 20, 12), (60, 60, 64), material="Slate")
    sc.part(st, "Roof", CF.new(ax, H + 22, cz1 - 6) * CF.rot_y(PI / 4), (10, 4, 10), (40, 40, 44), material="Slate")
    bell = sc.part(dec, "Part", CF.new(ax, H + 16, cz1 - 12.4), (3, 3.4, 3), (150, 110, 50), material="Metal", collide=False)
    sc.mesh(bell, "Sphere")
    sc.part(dec, "Part", CF.new(ax, H + 13, cz1 - 12.6), (2, 2, 0.2), (14, 12, 12), material="Slate", collide=False)
    for lx in (-4, 4):
        P.wardrobe(sc, lk, CF.new(cx1 - 2.2, 0, cz0 + 12 + (lx + 4) * 2.5) * CF.rot_y(PI / 2), color=P.WOOD_DARK)

    # boiler house: boilers, pipes, coal, generator #1, lockers
    bx0, bz0, bx1, bz1 = boiler
    for i in range(2):
        x = bx0 + 9 + i * 12
        sc.cyl(dec, "Part", (x, 0, bz1 - 6), (x, 9, bz1 - 6), 3.0, P.RUST, material="CorrodedMetal")
        sc.cyl(dec, "Part", (x, 9, bz1 - 6), (x, 11.9, bz1 - 6), 0.6, P.RUST_DARK, material="CorrodedMetal")
        P.pipe_run(sc, dec, [(x, 7, bz1 - 3), (x, 10.5, bz1 - 1.5), (bx0 + 1.5, 10.5, bz1 - 1.5)])
        sc.part(dec, "Part", CF.new(x, 5, bz1 - 9.05), (1.4, 1.4, 0.2), (220, 220, 200), material="SmoothPlastic", collide=False)
    coal = sc.part(dec, "Part", CF.new(bx1 - 6, 1.0, bz0 + 6), (8, 3, 6), (20, 20, 22), material="Slate")
    sc.mesh(coal, "Sphere")
    P.generator(sc, gens, CF.new(bx1 - 7, 0, (bz0 + bz1) / 2 + 2) * CF.rot_y(PI / 2))
    P.locker(sc, lk, CF.new(bx0 + 3, 0, bz0 + 1.7) * CF.rot_y(PI))
    P.writing(sc, dec, CF.new(bx1 - 0.6, 7, bz0 + 7) * CF.rot_y(PI / 2), "ОНО ЖИВЁТ В КОТЕЛЬНОЙ", size=(12, 2.2, 0.08))

    # bathhouse: tubs, showers, generator #2
    hx0, hz0, hx1, hz1 = bath
    for i in range(4):
        x = hx0 + 6 + i * 7
        sc.part(dec, "Part", CF.new(x, 1.2, hz1 - 4.5), (3.2, 2.4, 6.5), (215, 215, 205), material="SmoothPlastic")
        sc.part(dec, "Part", CF.new(x, 1.9, hz1 - 4.5), (2.4, 1.2, 5.6), (40, 50, 50) if i != 2 else P.BLOOD_DARK, material="Glass", transparency=0.2, collide=False)
        sc.cyl(dec, "Part", (x, 0, hz1 - 0.8), (x, 9, hz1 - 0.8), 0.15, P.STEEL, collide=False)
        sc.part(dec, "Part", CF.new(x, 9, hz1 - 1.6), (1.2, 0.3, 1.2), P.STEEL, material="Metal", collide=False)
    P.generator(sc, gens, CF.new(hx0 + 7, 0, (hz0 + hz1) / 2 - 3) * CF.rot_y(-PI / 2))
    P.blood_smear(sc, dec, CF.new(hx0 + 18, 5, hz0 + 0.6) * CF.rot_y(PI), length=5)
    P.locker(sc, lk, CF.new(hx0 + 20, 0, hz0 + 1.7) * CF.rot_y(PI), color=(200, 200, 194))
    P.sink(sc, dec, CF.new(hx1 - 12, 0, hz0 + 1.0) * CF.rot_y(PI))

    # garage: ambulance, barrels, crates, generator #3
    gx0, gz0, gx1, gz1 = garage
    ax_, az_ = gx0 + 18, gz0 + 16
    sc.part(dec, "Part", CF.new(ax_, 4.6, az_), (8, 7, 13), (200, 200, 190), material="CorrodedMetal")
    sc.part(dec, "Part", CF.new(ax_, 3.6, az_ - 8.5), (8, 5, 4), (200, 200, 190), material="CorrodedMetal")
    sc.part(dec, "Part", CF.new(ax_, 5.0, az_ - 10.5), (7, 2.2, 0.2), (40, 50, 58), material="Glass", transparency=0.3)
    for wx in (-4, 4):
        for wz in (-8, 4):
            sc.part(dec, "Part", CF.new(ax_ + wx, 1.3, az_ + wz) * CF.rot_z(PI / 2), (1.0, 2.6, 2.6), (20, 20, 20), material="SmoothPlastic", shape="Cylinder")
    P.poster(sc, dec, CF.new(ax_ + 4.05, 5.5, az_) * CF.rot_y(PI / 2), "✚", size=(3, 3))
    sc.part(dec, "Part", CF.new(ax_, 8.3, az_ - 5), (3, 0.6, 1), (200, 30, 30), material="Neon", collide=False)
    for i in range(3):
        P.barrel(sc, dec, CF.new(gx0 + 3 + i * 3, 0, gz1 - 3))
    P.crate(sc, dec, CF.new(gx1 - 4, 0, gz1 - 4))
    P.generator(sc, gens, CF.new(gx0 + 7, 0, gz0 + 4.5) * CF.rot_y(PI))
    P.locker(sc, lk, CF.new(gx1 - 1.7, 0, gz0 + 8) * CF.rot_y(PI / 2))

    # pump shed: generator #4
    px0, pz0, px1, pz1 = pump
    P.generator(sc, gens, CF.new((px0 + px1) / 2, 0, pz0 + 4.5) * CF.rot_y(PI))
    P.pipe_run(sc, dec, [(px0 + 1, 2, pz1 - 2), (px0 + 1, 2, pz0 + 2), (px1 - 1, 2, pz0 + 2)], radius=0.5)
    P.wardrobe(sc, lk, CF.new(px1 - 1.7, 0, pz1 - 7) * CF.rot_y(PI / 2))

    # paths -----------------------------------------------------------------------
    def path(x0, z0, x1, z1):
        P.slab(sc, st, "Path", min(x0, x1) - 4, min(z0, z1) - 4, max(x0, x1) + 4, max(z0, z1) + 4, 0.05, 0.1, (92, 88, 82), "Pavement")
    path(0, -132, 0, 40)
    path(-108, -20, 90, -20)
    path(84, -38, 84, -20)
    path(-108, 20, 84, 20)
    path(84, 20, 84, 65)
    path(-108, 20, -108, 60)
    path(-90, -25, -90, -20)
    path(-8, -80, 0, -80)
    path(84, 65, 90, 65)
    path(84, -38, 90, -38)
    path_segments = [(-4, -136, 4, 44), (-112, -24, 94, -16), (80, -42, 88, -16), (-112, 16, 88, 24), (80, 16, 88, 69),
                     (-112, 16, -104, 64), (-12, -84, 4, -76)]
    for (x, z) in [(10, -110), (10, -80), (10, -50), (-10, 0), (10, 30), (40, 28), (70, 28), (-40, 28), (-80, 28), (-115, 40),
                   (40, -28), (70, -12), (-40, -12), (-80, -28), (92, 40), (-10, -120)]:
        P.lamp_post(sc, dec, li, (x, 0, z), on_power=sc.chance(0.6))

    # playground, well, statue ------------------------------------------------------
    pgx, pgz = 45, -80
    for i in range(2):
        x = pgx + i * 9
        for sx in (-1, 1):
            sc.cyl(dec, "Post", (x + sx * 3, 0, pgz - 2), (x + sx * 3, 9, pgz), 0.2, P.RUST, material="CorrodedMetal")
            sc.cyl(dec, "Post", (x + sx * 3, 0, pgz + 2), (x + sx * 3, 9, pgz), 0.2, P.RUST, material="CorrodedMetal")
        sc.cyl(dec, "Post", (x - 3, 9, pgz), (x + 3, 9, pgz), 0.2, P.RUST, material="CorrodedMetal")
        for sx in (-0.7, 0.7):
            sc.cyl(dec, "Part", (x + sx, 9, pgz), (x + sx, 2.2, pgz + (0.8 if i else 0)), 0.04, (40, 40, 40), collide=False)
        sc.part(dec, "Part", CF.new(x, 2.1, pgz + (0.8 if i else 0)), (1.8, 0.2, 0.8), P.WOOD, material="Wood", collide=False)
    sc.part(dec, "Part", CF.new(pgx + 4, 0.5, pgz + 14) * CF.rot_z(PI / 2), (0.6, 8, 8), (150, 40, 40), material="CorrodedMetal", shape="Cylinder")
    for a in range(6):
        ang = a * PI / 3
        sc.cyl(dec, "Part", (pgx + 4, 0.8, pgz + 14), (pgx + 4 + math.cos(ang) * 3.6, 2.4, pgz + 14 + math.sin(ang) * 3.6), 0.1, P.STEEL, collide=False)
    sc.wedge(dec, "Part", CF.new(pgx + 22, 3, pgz + 2) * CF.rot_y(PI / 2), (3, 6, 10), (60, 90, 140), material="Metal")
    sc.part(dec, "Part", CF.new(pgx + 22, 3, pgz - 4), (3, 6, 2), (60, 60, 64), material="Metal")
    wx, wz = -50, -70
    for a in range(10):
        a0, a1 = a * 2 * PI / 10, (a + 1) * 2 * PI / 10
        sc.cyl(dec, "Part", (wx + math.cos(a0) * 3.5, 1.2, wz + math.sin(a0) * 3.5), (wx + math.cos(a1) * 3.5, 1.2, wz + math.sin(a1) * 3.5), 1.0, (100, 98, 92), material="Cobblestone")
    sc.part(dec, "Part", CF.new(wx, 0.2, wz) * CF.rot_z(PI / 2), (0.2, 6, 6), (8, 10, 12), material="Glass", shape="Cylinder", collide=False)
    for sx in (-1, 1):
        sc.part(dec, "Post", CF.new(wx + sx * 3.4, 4, wz), (0.5, 6, 0.5), P.WOOD_DARK, material="Wood")
    sc.part(dec, "Roof", CF.new(wx, 7.4, wz), (8.5, 0.5, 5), (60, 40, 30), material="WoodPlanks")
    sx_, sz_ = -35, 0
    sc.part(dec, "Pedestal", CF.new(sx_, 2, sz_), (5, 4, 5), (120, 118, 110), material="Concrete")
    sc.part(dec, "Part", CF.new(sx_ + 3, 1.0, sz_ + 3) * CF.rot_z(1.3), (2, 5.5, 1.6), (150, 148, 140), material="Marble", collide=False)
    sc.part(dec, "Head", CF.new(sx_ + 6.5, 0.8, sz_ + 3), (1.6, 1.6, 1.6), (150, 148, 140), material="Marble", collide=False, shape="Ball")
    P.writing(sc, dec, CF.new(sx_, 2.5, sz_ - 2.55), "ВОРОТА ПОД ТОКОМ", size=(5, 1.4, 0.08))

    # fence + south gate + exit --------------------------------------------------------
    FX, FZ0, FZ1 = 150, -130, 130
    P.fence_run(sc, dec, (-FX, 0, FZ0), (-11.5, 0, FZ0))
    P.fence_run(sc, dec, (11.5, 0, FZ0), (FX, 0, FZ0))
    P.fence_run(sc, dec, (-FX, 0, FZ1), (FX, 0, FZ1))
    P.fence_run(sc, dec, (-FX, 0, FZ0), (-FX, 0, FZ1))
    P.fence_run(sc, dec, (FX, 0, FZ0), (FX, 0, FZ1))
    P.exit_gate(sc, mp, CF.new(0, 0, FZ0), width=22, height=12, style="iron")
    P.exit_zone(sc, mp, CF.new(0, 0, FZ0 - 13), size=(30, 12, 20))
    P.exit_sign(sc, dec, CF.new(0, 14.5, FZ0 + 0.6) * CF.rot_y(PI), "ВЫХОД · ВОРОТА")
    for sx in (-1, 1):
        P.emergency_light(sc, li, CF.new(sx * 13, 10, FZ0 + 1))
    P.writing(sc, dec, CF.new(-30, 5, FZ0 + 0.3), "НЕ ПРИКАСАЙСЯ К ЗАБОРУ", size=(14, 2, 0.08))

    # forest: trees outside buildings/paths/playground ------------------------------------
    blocked = [(r[0] - 7, r[1] - 7, r[2] + 7, r[3] + 7) for r, _ in BUILDINGS.values()]
    blocked += [(p[0] - 3, p[1] - 3, p[2] + 3, p[3] + 3) for p in path_segments]
    blocked += [(pgx - 6, pgz - 8, pgx + 28, pgz + 20), (wx - 7, wz - 7, wx + 7, wz + 7), (sx_ - 6, sz_ - 6, sx_ + 10, sz_ + 6),
                (-20, FZ0 - 2, 20, FZ0 + 14)]

    def free(x, z, pad=0):
        return not any(b[0] - pad <= x <= b[2] + pad and b[1] - pad <= z <= b[3] + pad for b in blocked)

    trees = []
    tries = 0
    while len(trees) < 95 and tries < 5000:
        tries += 1
        edge = sc.chance(0.45)
        if edge:
            side = sc.rng.randrange(4)
            t = sc.rng.random() * 2 - 1
            x, z = [(t * 140, 120), (t * 140, -120), (140, t * 120), (-140, t * 120)][side]
            x += sc.jitter(6)
            z += sc.jitter(6)
        else:
            x, z = sc.jitter(140), sc.jitter(120)
        if not free(x, z) or any((x - a) ** 2 + (z - b) ** 2 < 49 for a, b in trees):
            continue
        trees.append((x, z))
        P.tree(sc, dec, (x, 0, z), height=22 + sc.rng.random() * 14, trunk_r=0.8 + sc.rng.random() * 0.6)
    for _ in range(40):
        x, z = sc.jitter(145), sc.jitter(125)
        if free(x, z, 1):
            p = sc.part(dec, "Hedge", CF.new(x, 1.2, z), (3 + sc.rng.random() * 3, 2.6, 3 + sc.rng.random() * 3), sc.vary((24, 40, 26), 8), material="Grass", collide=False)
            sc.mesh(p, "Sphere")

    # outdoor AI nodes on a grid, away from buildings/trees/fence
    x = -138
    while x <= 138:
        z = -122
        while z <= 122:
            inside = any(r[0] - 3 <= x <= r[2] + 3 and r[1] - 3 <= z <= r[3] + 3 for r, _ in BUILDINGS.values())
            near_tree = any((x - a) ** 2 + (z - b) ** 2 < 16 for a, b in trees)
            if not inside and not near_tree:
                P.node(sc, nodes, (x, 3, z))
            z += 14
        x += 14
    # door thresholds so the monster can path in/out
    for name, (rect, doors) in BUILDINGS.items():
        x0, z0, x1, z1 = rect
        for side, off in doors:
            cx, cz = (x0 + x1) / 2 + off, (z0 + z1) / 2 + off
            pt = {"S": (cx, z0 - 5), "N": (cx, z1 + 5), "W": (x0 - 5, cz), "E": (x1 + 5, cz)}[side]
            P.node(sc, nodes, (pt[0], 3, pt[1]))

    # pickups: inside rooms + a few outdoors (sheds, playground, well)
    indoor = [bed_w, bed_n, dining, play, reception, chapel, boiler, bath, garage, pump]
    for i in range(16):
        P.spawn_point(sc, fuse, rand_in(sc, indoor[i % len(indoor)], 6))
    for i in range(14):
        P.spawn_point(sc, bat, rand_in(sc, indoor[i % len(indoor)], 6))
    for (x, z) in [(pgx + 4, pgz + 6), (wx + 6, wz), (sx_, sz_ - 6), (60, 0), (-70, 40), (100, 0), (-120, 0), (30, -110)]:
        P.spawn_point(sc, bat, (x, 0.5, z))
    return mp
