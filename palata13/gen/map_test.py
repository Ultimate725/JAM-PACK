"""Smoke-test map: one room with every prop (not shipped)."""
import math
from buildkit.cframe import CF
from gen import props as P

CEILING_Y = 11.5


def build(sc, parent):
    mp = sc.folder(parent, "Test")
    st = sc.folder(mp, "Structure"); dec = sc.folder(mp, "Decor"); li = sc.folder(mp, "Lights")
    lk = sc.folder(mp, "Lockers"); sp = sc.folder(mp, "Spawns"); fz = sc.folder(sp, "Fuse"); bz = sc.folder(sp, "Battery")
    nodes = sc.folder(mp, "AINodes"); gens = sc.folder(mp, "Generators")
    P.slab(sc, st, "Floor", -40, -40, 40, 40, -0.5, 1, P.FLOOR, "Concrete")
    P.slab(sc, st, "Ceiling", -40, -40, 40, 40, 12.5, 1, P.CEIL, "Concrete")
    P.wall(sc, st, (-40, -40), (40, -40), 12, wainscot=(P.WAINSCOT, 3.2))
    P.wall(sc, st, (40, -40), (40, 40), 12, wainscot=(P.WAINSCOT, 3.2))
    P.wall(sc, st, (40, 40), (-40, 40), 12, wainscot=(P.WAINSCOT, 3.2))
    P.wall(sc, st, (-40, 40), (-40, -40), 12, wainscot=(P.WAINSCOT, 3.2))
    P.door_frame(sc, st, CF.new(0, 0, -40))
    P.door(sc, dec, CF.new(0, 0, -40), open_angle=0.8)
    P.ceiling_lamp(sc, li, (0, 11.7, 0))
    P.ceiling_lamp(sc, li, (20, 11.7, 0), kind="FlickerLamp", rot=math.pi / 2)
    P.emergency_light(sc, li, CF.new(-39, 10, 0))
    P.wall_lamp(sc, li, CF.new(39.5, 7, 10) * CF.rot_y(math.pi / 2))
    P.locker(sc, lk, CF.new(-30, 0, 38.5) * CF.rot_y(0))
    P.wardrobe(sc, lk, CF.new(-25, 0, 38.5))
    P.generator(sc, gens, CF.new(25, 0, 25))
    P.exit_gate(sc, mp, CF.new(0, 0, 39))
    P.exit_zone(sc, mp, CF.new(0, 0, 45))
    P.marker(sc, mp, "MonsterSpawn", (30, 2, -30))
    sc.spawn_location(mp, CF.new(-30, -0.45, -30))
    for i in range(5):
        P.node(sc, nodes, (i * 10 - 20, 3, 0)); P.spawn_point(sc, fz, (i * 10 - 20, 1, 10)); P.spawn_point(sc, bz, (i * 10 - 20, 1, -10))
    P.writing(sc, dec, CF.new(-10, 6, -39.4), "ОНО НЕ СПИТ")
    P.room_sign(sc, dec, CF.new(6, 9, -39.4), "ПАЛАТА 13")
    P.exit_sign(sc, dec, CF.new(0, 10.5, 38.4))
    P.blood_pool(sc, dec, (10, 0, 10)); P.blood_smear(sc, dec, CF.new(20, 5, -39.4)); P.papers(sc, dec, (-10, 0, 10)); P.debris(sc, dec, (-20, 0, -20))
    P.bed(sc, dec, CF.new(-30, 0, 0), bloody=True); P.gurney(sc, dec, CF.new(-20, 0, -25)); P.wheelchair(sc, dec, CF.new(-10, 0, -25))
    P.iv_stand(sc, dec, CF.new(-26, 0, 4)); P.cabinet(sc, dec, CF.new(10, 0, 38.9), open_door=True); P.desk(sc, dec, CF.new(20, 0, -20))
    P.chair(sc, dec, CF.new(30, 0, -20), fallen=True); P.sink(sc, dec, CF.new(30, 0, 38.9)); P.toilet(sc, dec, CF.new(35, 0, 38)); P.shelf(sc, dec, CF.new(-36, 0, 20) * CF.rot_y(math.pi / 2))
    P.barrel(sc, dec, CF.new(30, 0, 5)); P.crate(sc, dec, CF.new(34, 0, 10)); P.pipe_run(sc, dec, [(-39, 9, -30), (-39, 9, 30), (-30, 9, 30)])
    P.vent(sc, dec, CF.new(15, 9, -39.4)); P.extinguisher(sc, dec, CF.new(-5, 0, -39.4)); P.poster(sc, dec, CF.new(-15, 6, -39.4), "НЕ ШУМИ")
    P.body_bag(sc, dec, CF.new(0, 0, 20)); P.hanging_body_sheet(sc, dec, CF.new(10, 0, 25)); P.candle(sc, dec, li, (5, 0, 5))
    P.tree(sc, dec, (-60, 0, 0)); P.lamp_post(sc, dec, li, (60, 0, 0)); P.fence_run(sc, dec, (50, 0, -40), (50, 0, 40))
    return mp
