"""Lobby upgrades: kiosks (касса / лавка фонарей / аптека / регистратура), the hospital plan board,
gate consoles, the new menu-corridor scene props (slamming door, rolling wheelchair, swinging lamp,
extra approach point P4) and the new MenuMonster."""
import math
from buildkit.cframe import CF
from buildkit import rbxml as X
from gen import props as P
from gen.monster import build_monster

PI = math.pi


def prompt_part(sc, lobby, name, pos):
    return sc.part(lobby, name, CF(pos), (2, 2, 2), (0, 0, 0), transparency=1, collide=False, can_query=False)


def kiosk(sc, decor, lights, cf, title, accent, sign_style="gold"):
    """Market stall: counter, back wall with shelves, awning, hanging bulbs. Faces -Z of cf."""
    sc.part(decor, "Part", P.at(cf, 0, 0.15, 0), (14, 0.3, 9), (70, 62, 56), material="WoodPlanks")
    sc.part(decor, "Part", P.at(cf, 0, 1.6, -3.2), (12, 3.0, 1.6), (84, 64, 46), material="WoodPlanks")  # counter
    sc.part(decor, "Part", P.at(cf, 0, 3.2, -3.2), (12.4, 0.25, 2.0), (120, 96, 70), material="Wood")
    sc.part(decor, "Part", P.at(cf, 0, 4.5, 4.1), (14, 9, 0.6), (60, 56, 52), material="WoodPlanks")  # back wall
    for sx in (-1, 1):
        sc.part(decor, "Part", P.at(cf, sx * 6.7, 4.5, -4.3), (0.5, 9, 0.5), (50, 44, 40), material="Wood")
        sc.part(decor, "Part", P.at(cf, sx * 6.7, 4.5, 4.1), (0.5, 9, 0.5), (50, 44, 40), material="Wood")
    sc.part(decor, "Part", P.at(cf, 0, 9.3, 0) * CF.rot_x(0.12), (15, 0.3, 10), accent, material="Fabric")  # awning
    for i in range(7):
        sc.part(decor, "Part", P.at(cf, -6 + i * 2, 8.5, -5.2), (1.6, 1.2, 0.1), accent if i % 2 else (230, 225, 210), material="Fabric", collide=False)
    board = sc.part(decor, "ShopSign", P.at(cf, 0, 7.2, -4.0), (11, 1.8, 0.2), (14, 10, 10), material="SmoothPlastic", collide=False)
    sc.sign(board, title, sign_style)
    for y in (3.9, 6.0):
        sc.part(decor, "Part", P.at(cf, 0, y, 3.5), (11, 0.15, 1.2), (110, 90, 66), material="Wood", collide=False)
    for i in range(3):
        bulb = sc.part(lights, "FlickerLamp", P.at(cf, -4 + i * 4, 8.6, -1), (0.5, 0.7, 0.5), (255, 220, 170), material="Neon", collide=False, cast_shadow=False)
        sc.pointlight(bulb, (255, 200, 140), 14, 0.8, True)
        sc.cyl(decor, "Part", P.at(cf, -4 + i * 4, 9.0, -1).p, P.at(cf, -4 + i * 4, 9.6, -1).p, 0.03, (30, 30, 30), collide=False)
    P.papers(sc, decor, P.at(cf, 0, 0.3, -5).p, n=4, radius=2.5)
    return cf


def hooded_vendor(sc, decor, cf, robe=(40, 36, 44)):
    """Faceless hooded figure behind a counter."""
    sc.ellipsoid(decor, "Part", P.at(cf, 0, 3.6, 0), (2.6, 7.2, 2.2), robe, material="Fabric")
    sc.ellipsoid(decor, "Part", P.at(cf, 0, 7.4, 0.1), (1.9, 2.1, 2.0), sc.vary(robe, 6), material="Fabric")
    sc.ellipsoid(decor, "Part", P.at(cf, 0, 7.2, -0.75), (1.2, 1.5, 0.5), (14, 10, 12), material="SmoothPlastic")  # void face
    for sx in (-1, 1):
        sc.cyl(decor, "Part", P.at(cf, sx * 1.2, 5.5, -0.3).p, P.at(cf, sx * 0.6, 3.0, -1.6).p, 0.32, robe, material="Fabric", collide=False)
        sc.ellipsoid(decor, "Part", P.at(cf, sx * 0.55, 2.9, -1.7), (0.7, 0.4, 0.9), (180, 172, 150), material="SmoothPlastic", collide=False)


def lights_kiosk(sc, decor, lights, cf):
    kiosk(sc, decor, lights, cf, "ЛАВКА ФОНАРЕЙ", (120, 100, 40))
    hooded_vendor(sc, decor, P.at(cf, 0, 0, 1.5))
    colors = [(255, 236, 205), (200, 225, 255), (150, 255, 120), (140, 255, 245), (255, 200, 90), (180, 190, 255), (255, 140, 60), (255, 50, 50)]
    for i, c in enumerate(colors):
        x = -4.8 + i * 1.4
        y = 4.3 if i % 2 == 0 else 6.4
        body = sc.part(decor, "Part", P.at(cf, x, y, 3.3) * CF.rot_x(PI / 2), (1.2, 0.5, 0.5), (60, 60, 62), material="Metal", collide=False)
        lens = sc.part(lights, "Lamp", P.at(cf, x, y, 2.6), (0.5, 0.5, 0.15), c, material="Neon", collide=False, cast_shadow=False)
        sc.pointlight(lens, c, 5, 0.6, False)
        _ = body


def pharmacy_kiosk(sc, decor, lights, cf):
    kiosk(sc, decor, lights, cf, "АПТЕКА · ПЕРКИ", (40, 100, 70))
    hooded_vendor(sc, decor, P.at(cf, 0, 0, 1.5), robe=(200, 196, 190))
    for i in range(10):
        x = -5 + i * 1.1
        y = 4.3 if i % 2 == 0 else 6.4
        col = sc.pick([(200, 190, 160), (120, 60, 50), (90, 120, 100), (230, 230, 220), (60, 90, 140)])
        sc.part(decor, "Part", P.at(cf, x, y + 0.35, 3.3), (0.5, 0.7, 0.5), col, material="Glass", transparency=0.2, collide=False)
    cross = sc.part(decor, "Part", P.at(cf, 5.5, 8.1, -4.1), (1.6, 0.4, 0.2), (60, 220, 90), material="Neon", collide=False)
    sc.part(decor, "Part", P.at(cf, 5.5, 8.1, -4.1), (0.4, 1.6, 0.2), (60, 220, 90), material="Neon", collide=False)
    sc.pointlight(cross, (60, 220, 90), 8, 0.6, False)
    sc.part(decor, "Part", P.at(cf, -3, 3.45, -3.2), (1.0, 0.25, 1.0), (200, 60, 60), material="SmoothPlastic", collide=False)  # pill tray
    for i in range(6):
        sc.ellipsoid(decor, "Part", P.at(cf, -3.3 + (i % 3) * 0.3, 3.65, -3.4 + (i // 3) * 0.3), (0.2, 0.12, 0.2), (240, 240, 230), collide=False)


def registry_desk(sc, decor, lights, cf):
    kiosk(sc, decor, lights, cf, "РЕГИСТРАТУРА · ТИТУЛЫ", (90, 90, 110), sign_style="room")
    hooded_vendor(sc, decor, P.at(cf, 0, 0, 1.5), robe=(70, 80, 100))
    for i in range(14):
        sc.part(decor, "Part", P.at(cf, -5.4 + (i % 7) * 1.8, 4.3 + (i // 7) * 2.1 + 0.4, 3.3), (1.4, 0.8, 0.9), sc.vary(P.PAPER, 20), material="SmoothPlastic", collide=False)
    sc.part(decor, "Part", P.at(cf, 2.5, 3.6, -3.2), (1.6, 0.5, 1.1), (40, 40, 44), material="Metal", collide=False)  # typewriter
    sc.part(decor, "Part", P.at(cf, -2.5, 3.5, -3.0), (0.3, 0.3, 0.3), (200, 180, 60), material="Metal", collide=False)  # bell
    tag = sc.part(decor, "Part", P.at(cf, 0, 5.0, -3.9), (3.2, 0.9, 0.08), (230, 225, 210), material="SmoothPlastic", collide=False)
    sc.sign(tag, "КАК ВАС ЗАПИСАТЬ?", "plain")


def maps_board(sc, decor, lights, cf):
    """Hospital plan on the wall. cf on the wall surface, facing out (-Z)."""
    sc.part(decor, "Part", P.at(cf, 0, 7, 0.2), (14, 9, 0.3), (72, 60, 46), material="Wood")
    board = sc.part(decor, "Part", P.at(cf, 0, 7, 0.0), (13, 8, 0.1), (190, 182, 160), material="SmoothPlastic")
    sc.sign(board, "ПЛАН БОЛЬНИЦЫ\n🏥 ПАЛАТА 13 · 🧊 МОРГ · 🌲 САНАТОРИЙ\nкарта · сложность · игроки — на пульте у врат", "plain")
    for i in range(6):
        sc.part(decor, "Part", P.at(cf, -5 + i * 2, 3.2 + sc.jitter(0.8), -0.1) * CF.rot_z(sc.jitter(0.3)), (1.5, 1.1, 0.05), sc.vary(P.PAPER, 25), material="SmoothPlastic", collide=False)
    pin = sc.part(decor, "Part", P.at(cf, 3.5, 8.5, -0.12), (0.3, 0.3, 0.2), (200, 30, 30), material="SmoothPlastic", collide=False)
    _ = pin
    lamp = sc.part(lights, "FlickerLamp", P.at(cf, 0, 12.2, -1.2), (3, 0.3, 0.6), (255, 230, 200), material="Neon", collide=False, cast_shadow=False)
    sc.spotlight(lamp, "Bottom", 90, 16, 1.2, (255, 230, 200), True)


def console(sc, decor, lights, cf, label):
    """Gate control pedestal with a glowing screen. Faces -Z."""
    sc.part(decor, "Part", P.at(cf, 0, 1.6, 0), (2.6, 3.2, 1.6), (44, 46, 50), material="Metal")
    sc.part(decor, "Part", P.at(cf, 0, 3.5, -0.3) * CF.rot_x(-0.5), (2.6, 0.5, 2.0), (40, 42, 46), material="Metal")
    screen = sc.part(decor, "Part", P.at(cf, 0, 3.85, -0.7) * CF.rot_x(-0.5), (2.2, 0.08, 1.3), (40, 160, 120), material="Neon", collide=False)
    sc.pointlight(screen, (60, 200, 150), 8, 0.6, False)
    sign = sc.part(decor, "Part", P.at(cf, 0, 5.2, 0.2), (3.0, 0.9, 0.1), (14, 10, 10), material="SmoothPlastic", collide=False)
    sc.sign(sign, label, "gold")
    for i in range(4):
        b = sc.part(decor, "Part", P.at(cf, -0.9 + i * 0.6, 3.25, -0.95) * CF.rot_x(-0.5), (0.35, 0.1, 0.35), sc.pick([(200, 40, 40), (230, 200, 60), (60, 200, 90)]), material="Neon", collide=False)
        _ = b
    sc.cyl(decor, "Part", P.at(cf, 0.8, 0.3, 0.9).p, P.at(cf, 0.8, 0.3, 6).p, 0.1, (20, 20, 20), collide=False)
    _ = lights


def menu_scene(sc, lobby, decor, lights, points):
    """Props for the main-menu corridor (x 194..206, z -44..40; camera at z=34 looking -Z)."""
    scene = sc.folder(lobby, "MenuScene")
    # extra approach point right in front of the camera
    sc.part(points, "P4", CF.new(200.6, 5, 25.5), (1, 1, 1), (255, 0, 0), transparency=1, collide=False, can_query=False)
    # slamming door on the east wall (hinge value tells the client where to pivot)
    door = sc.part(scene, "SlamDoor", CF.new(205.85, 5.2, -4.0) * CF.rot_y(PI / 2) * CF.new(0, 0, 0), (4.0, 10.4, 0.25), (96, 110, 96), material="Wood", collide=False)
    sc.numval(door, "Hinge", 2.0)
    sc.part(scene, "Part", CF.new(205.9, 5.5, -6.3), (0.3, 11, 0.5), P.WOOD_DARK, material="Wood", collide=False)
    sc.part(scene, "Part", CF.new(205.9, 5.5, -1.7), (0.3, 11, 0.5), P.WOOD_DARK, material="Wood", collide=False)
    sc.part(scene, "Part", CF.new(205.9, 11.2, -4.0), (0.3, 0.5, 5.2), P.WOOD_DARK, material="Wood", collide=False)
    rs = sc.part(scene, "Part", CF.new(205.7, 12.3, -4.0) * CF.rot_y(-PI / 2), (3.6, 0.9, 0.1), (30, 32, 30), material="SmoothPlastic", collide=False)
    sc.sign(rs, "ПАЛАТА 13", "room")
    # wheelchair that rolls towards the camera during a blackout
    P.wheelchair(sc, scene, CF.new(197.2, 0, -18) * CF.rot_y(PI))
    # swinging lamp: short chain + shade + bulb (the model pivots as a whole)
    lamp = sc.model(scene, "SwingLamp")
    sc.cyl(lamp, "Chain", (200, 12.9, 8), (200, 10.6, 8), 0.06, (40, 40, 40), collide=False)
    sc.part(lamp, "Shade", CF.new(200, 10.2, 8), (2.6, 0.8, 2.6), (70, 72, 70), material="Metal", collide=False)
    bulb = sc.part(lights, "FlickerLamp", CF.new(200, 9.75, 8), (0.6, 0.5, 0.6), (255, 225, 190), material="Neon", collide=False, cast_shadow=False)
    sc.pointlight(bulb, (255, 215, 170), 22, 1.4, True)
    bulb_parent = lamp  # keep the bulb inside the model so it swings with it
    lights.remove(bulb)
    bulb_parent.append(bulb)
    # corridor dressing
    P.gurney(sc, decor, CF.new(196.8, 0, -1) * CF.rot_y(0.2), sheet=True)
    P.iv_stand(sc, decor, CF.new(195.6, 0, 3.5))
    P.iv_stand(sc, decor, CF.new(204.3, 0, -24))
    P.blood_pool(sc, decor, (199, 0, -26), radius=1.8)
    for i in range(10):
        q = CF.new(199.5 + sc.jitter(0.6), 0.03, -24 + i * 2.2) * CF.rot_y(sc.jitter(0.3))
        sc.part(decor, "Smear", q, (0.5 + sc.rng.random() * 0.6, 0.04, 2.0), P.BLOOD_DARK, material="Granite", collide=False)
    P.blood_smear(sc, decor, CF.new(194.1, 5.5, 10) * CF.rot_y(-PI / 2), length=4)
    P.papers(sc, decor, (201, 0, 14), n=12, radius=4)
    P.debris(sc, decor, (203, 0, -36), n=8, radius=2.5)
    P.writing(sc, decor, CF.new(200, 7.5, -43.9), "НЕ ОБОРАЧИВАЙСЯ", size=(10, 2.6, 0.08))
    P.writing(sc, decor, CF.new(194.1, 8.5, -14) * CF.rot_y(-PI / 2), "13 13 13 13 13", size=(9, 1.8, 0.08))
    P.poster(sc, decor, CF.new(205.9, 6.5, 20) * CF.rot_y(PI / 2), "ТИХО. ПАЦИЕНТЫ СПЯТ.", size=(3.4, 2.2))
    P.extinguisher(sc, decor, CF.new(194.2, 0, 30) * CF.rot_y(-PI / 2))
    P.vent(sc, decor, CF.new(205.9, 11.5, 30) * CF.rot_y(PI / 2))
    for i in range(6):
        z = -40 + i * 13
        sc.cyl(decor, "Part", (194.0, 12.4, z), (194.0, 12.4 - 0.8 - sc.rng.random(), z + 4), 0.05, (30, 30, 30), collide=False)
    for i in range(3):
        cf = CF.new(197 + i * 3, 12.6, -30 + i * 9) * CF.angles(0.4 + sc.jitter(0.3), sc.jitter(0.4), 0)
        sc.part(decor, "HangingTile", cf, (3.8, 0.15, 3.8), (120, 118, 110), material="Concrete", collide=False)
    P.exit_sign(sc, decor, CF.new(200, 12.2, 39.4) * CF.rot_y(PI), "ВЫХОД")
    sc.part(decor, "Part", CF.new(200, 1.0, -41), (4, 2.0, 2.2), (60, 56, 52), material="Fabric", collide=False)  # rag heap
    return scene


def upgrade(sc, lobby):
    decor = X.child(lobby, "Decor")
    lights = X.child(lobby, "Lights")
    points = X.child(lobby, "MenuMonsterPoints")
    # kiosks along the south wall (z=30.5), facing north into the hall
    lights_kiosk(sc, decor, lights, CF.new(-24, 0, 25))
    prompt_part(sc, lobby, "LightsPrompt", (-24, 4.5, 21))
    pharmacy_kiosk(sc, decor, lights, CF.new(0, 0, 25))
    prompt_part(sc, lobby, "PharmacyPrompt", (0, 4.5, 21))
    registry_desk(sc, decor, lights, CF.new(24, 0, 25))
    prompt_part(sc, lobby, "TitlesPrompt", (24, 4.5, 21))
    # hospital plan board on the east wall
    maps_board(sc, decor, lights, CF.new(39.7, 0, -19) * CF.rot_y(PI / 2))
    prompt_part(sc, lobby, "MapsPrompt", (37, 5, -19))
    # gate consoles (south-west corner of each gate circle)
    for i, gx in enumerate((-24, 0, 24), 1):
        cf = CF.new(gx - 7.5, 0, -19)
        console(sc, decor, lights, cf, "ПУЛЬТ ВРАТ " + ["I", "II", "III"][i - 1])
        prompt_part(sc, lobby, "Console%d" % i, (gx - 7.5, 3, -19))
    # floor arrows from spawn to the gates
    for i, gx in enumerate((-24, 0, 24)):
        for k in range(3):
            a = sc.part(decor, "Part", CF.new(gx, 0.03, -2 - k * 6) * CF.rot_y(0), (1.6, 0.05, 2.2), (120, 10, 10), material="Neon", transparency=0.5, collide=False)
            sc.mesh(a, "Wedge")
    menu_scene(sc, lobby, decor, lights, points)
    # new menu monster (same name the client expects); parked at P1 in the menu corridor
    old = X.child(lobby, "MenuMonster", "Model")
    if old is not None:
        lobby.remove(old)
    monster = build_monster(sc, lobby, "MenuMonster", "Patient")
    p1 = X.get_cframe(X.child(points, "P1"))
    for e in monster.iter("Item"):
        cf = X.get_cframe(e)
        if cf is not None and e.get("class") in ("Part", "WedgePart"):
            X.set_prop(e, "CoordinateFrame", "CFrame", cf.with_pos(cf.p + p1.p.__class__(p1.p.x, 0, p1.p.z)))
