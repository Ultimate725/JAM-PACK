"""Hospital (base map) upgrades applied to the loaded base document:
   - Generators folder: the original big generator + 3 new ones in distant wings
   - extra gore / story props near the new generators
   - the Map folder is renamed and parked in ServerStorage.Maps.Hospital by build.py
"""
import math
from buildkit.cframe import CF
from buildkit import rbxml as X
from gen import props as P

NEW_GENERATORS = [
    ((148.0, 0.0, -121.0), math.pi / 2),
    ((-104.0, 0.0, -106.0), -math.pi / 2),
    ((-134.0, 0.0, 125.0), 0.0),
]


def upgrade(sc, mapfolder):
    gens = X.child(mapfolder, "Generators")
    if gens is None:
        gens = sc.folder(mapfolder, "Generators")
    old = X.child(mapfolder, "Generator", "Model")
    if old is not None:
        mapfolder.remove(old)
        gens.append(old)
    decor = X.child(mapfolder, "Decor")
    lights = X.child(mapfolder, "Lights")
    for pos, rot in NEW_GENERATORS:
        cf = CF(pos) * CF.rot_y(rot)
        P.generator(sc, gens, cf)
        # cables snaking to the wall, oil, a warning board and a caged lamp above
        P.blood_pool(sc, decor, (cf * CF.new(-4, 0, -5)).p, radius=1.4)
        P.papers(sc, decor, (cf * CF.new(4, 0, -5)).p, n=5, radius=1.5)
        P.poster(sc, decor, cf * CF.new(-6.5, 6.5, 2.4) * CF.rot_y(math.pi), "ВКЛЮЧИ СВЕТ.\nОТКРОЙ ВОРОТА.", style="blood", size=(4, 2.4))
        P.wall_lamp(sc, lights, cf * CF.new(6, 7.5, 2.4) * CF.rot_y(math.pi), kind="Emergency")
    # story: every generator room gets a scrawl
    P.writing(sc, decor, CF.new(4, 6, -97.5), "ЧЕТЫРЕ ГЕНЕРАТОРА. ОДИН ВЫХОД.", size=(14, 2.2, 0.08))
    return gens
