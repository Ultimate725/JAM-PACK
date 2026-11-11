"""Procedural 'Patient 13' monster rig: skeleton bones + Motor6D joints (animator-compatible names)
and a much denser layer of welded visual parts. Two variants:
  - 'Patient'  : sighted, glowing eyes
  - 'Blind'    : eyes sewn shut, bandaged skull, enlarged ear holes, listens (used by blind difficulties)
"""
import math
from buildkit.cframe import CF, V3
from buildkit import rbxml as X

SKIN = (176, 170, 150)
SKIN_DARK = (128, 118, 100)
BRUISE = (96, 84, 110)
MEAT = (118, 22, 24)
MEAT_DARK = (64, 10, 12)
BONE = (214, 205, 180)
GOWN = (150, 168, 150)
GOWN_DIRTY = (112, 124, 108)
BLOOD = (90, 6, 8)
LEATHER = (52, 36, 28)
RUST = (104, 72, 52)
STEEL = (150, 150, 145)
HAIR = (22, 18, 16)
TOOTH = (205, 190, 150)

# Rest-pose bone positions (world space, identity rotation). Legs keep the base proportions so
# HipHeight 2.5 still puts the feet on the floor; torso/neck/arms are longer and more hunched.
BONES = {
    "HumanoidRootPart": (0, 5, 0),
    "Pelvis": (0, 5.4, 0.2), "Chest": (0, 6.3, 0.0), "NeckB": (0, 8.9, -1.2), "Head": (0, 9.5, -2.2), "Jaw": (0, 9.3, -2.6),
    "LUpperArm": (-1.7, 8.4, -0.9), "LForeArm": (-2.0, 5.1, -1.2), "LHand": (-2.1, 1.9, -1.7),
    "RUpperArm": (1.7, 8.4, -0.9), "RForeArm": (2.0, 5.1, -1.2), "RHand": (2.1, 1.9, -1.7),
    "LThigh": (-0.75, 5.2, 0.25), "LShin": (-0.85, 2.9, -0.35), "LFoot": (-0.85, 0.55, 0.35),
    "RThigh": (0.75, 5.2, 0.25), "RShin": (0.85, 2.9, -0.35), "RFoot": (0.85, 0.55, 0.35),
}
FINGER_Z = [-0.3, -0.1, 0.1, 0.3]
for side, sx in (("L", -1), ("R", 1)):
    hx, hy, hz = BONES[side + "Hand"]
    for i, fz in enumerate(FINGER_Z, 1):
        BONES["%sF%dA" % (side, i)] = (hx + sx * 0.05, hy - 0.8, hz + fz)
        BONES["%sF%dB" % (side, i)] = (hx + sx * 0.08, hy - 1.55, hz + fz - 0.05)

JOINTS = [
    ("RootJoint", "HumanoidRootPart", "Pelvis"), ("Waist", "Pelvis", "Chest"), ("NeckBase", "Chest", "NeckB"),
    ("Neck", "NeckB", "Head"), ("Jaw", "Head", "Jaw"),
    ("LShoulder", "Chest", "LUpperArm"), ("LElbow", "LUpperArm", "LForeArm"), ("LWrist", "LForeArm", "LHand"),
    ("RShoulder", "Chest", "RUpperArm"), ("RElbow", "RUpperArm", "RForeArm"), ("RWrist", "RForeArm", "RHand"),
    ("LHip", "Pelvis", "LThigh"), ("LKnee", "LThigh", "LShin"), ("LAnkle", "LShin", "LFoot"),
    ("RHip", "Pelvis", "RThigh"), ("RKnee", "RThigh", "RShin"), ("RAnkle", "RShin", "RFoot"),
]
for side in "LR":
    for i in range(1, 5):
        JOINTS.append(("%sF%da" % (side, i), side + "Hand", "%sF%dA" % (side, i)))
        JOINTS.append(("%sF%db" % (side, i), "%sF%dA" % (side, i), "%sF%dB" % (side, i)))


class MonsterBuilder:
    def __init__(self, scene, parent, name="Monster", variant="Patient"):
        self.sc = scene
        self.variant = variant
        self.model = scene.model(parent, name)
        self.bones = {}
        self.visuals = 0
        X.item(scene.doc, "StringValue", "Variant", [("string", "Value", variant)], parent=self.model)

    # -- skeleton ---------------------------------------------------------------
    def build_skeleton(self):
        sc = self.sc
        for name, pos in BONES.items():
            if name == "HumanoidRootPart":
                p = sc.part(self.model, name, CF(pos), (3, 5, 2), (90, 90, 90), transparency=1, anchored=False, collide=True)
            else:
                p = sc.part(self.model, name, CF(pos), (0.3, 0.3, 0.3), (90, 90, 90), transparency=1, anchored=False,
                            collide=False, massless=True)
            self.bones[name] = p
        for jname, p0, p1 in JOINTS:
            a, b = V3(*BONES[p0]), V3(*BONES[p1])
            sc.motor6d(self.bones[p1], jname, self.bones[p0], self.bones[p1], CF(b - a))
        sc.attachment(self.bones["Head"], "FaceCam", CF.new(0, 0.1, -1.0))
        sc.attachment(self.bones["Chest"], "Sonar", CF.new(0, 1.0, -0.6))
        sc.humanoid(self.model, walkspeed=9, hipheight=2.5)

    # -- visual helpers ----------------------------------------------------------
    def attach(self, bone, name, cf, size, color, **kw):
        """Part at world CF (rest pose), welded to bone."""
        kw.setdefault("material", "SmoothPlastic")
        kw.setdefault("collide", False)
        kw.setdefault("anchored", False)
        kw.setdefault("massless", True)
        p = self.sc.part(self.model, name, cf, size, color, **kw)
        b = self.bones[bone]
        self.sc.weld(b, p, CF(cf.p - V3(*BONES[bone]), cf.r))
        self.visuals += 1
        return p

    def blob(self, bone, name, pos, size, color, rot=None, **kw):
        cf = CF(pos) * (rot or CF())
        p = self.attach(bone, name, cf, size, color, **kw)
        self.sc.mesh(p, "Sphere")
        return p

    def tube(self, bone, name, a, b, r, color, **kw):
        a, b = V3(*a), V3(*b)
        d = b - a
        mid = a + d * 0.5
        look = CF.lookat(mid, mid + d) if d.mag > 1e-6 else CF(mid)
        cf = look * CF.rot_y(math.pi / 2)
        kw.setdefault("shape", "Cylinder")
        return self.attach(bone, name, cf, (d.mag, r * 2, r * 2), color, **kw)

    def limb(self, bone, name, a, b, r0, r1, color, segs=3, **kw):
        """Tapered limb from a (radius r0) to b (radius r1) as overlapping cylinder segments + joint balls."""
        a, b = V3(*a), V3(*b)
        for i in range(segs):
            t0, t1 = i / segs, (i + 1) / segs
            p0, p1 = a.lerp(b, t0), a.lerp(b, t1)
            r = r0 + (r1 - r0) * (t0 + t1) / 2
            ext = (p1 - p0).unit * 0.12
            self.tube(bone, name, p0 - ext, p1 + ext, r, self.sc.vary(color, 6), **kw)

    # -- body ----------------------------------------------------------------------
    def build_body(self):
        sc = self.sc
        B = {k: V3(*v) for k, v in BONES.items()}
        skin = SKIN if self.variant == "Patient" else (168, 172, 162)

        # pelvis + spine
        self.blob("Pelvis", "Flesh", B["Pelvis"] + V3(0, -0.1, 0), (2.4, 1.6, 1.5), skin)
        for i in range(8):
            t = i / 7
            pos = B["Pelvis"].lerp(B["NeckB"], t) + V3(0, 0, 0.55 + 0.2 * math.sin(t * math.pi))
            bone = "Pelvis" if t < 0.3 else "Chest"
            self.blob(bone, "Spine", pos, (0.42, 0.34, 0.42), BONE, material="Slate")
        # chest cage: sunken, ribs visible through skin
        self.blob("Chest", "Flesh", B["Chest"] + V3(0, 1.0, -0.1), (2.9, 2.6, 1.9), skin)
        self.blob("Chest", "Flesh", B["Chest"] + V3(0, -0.2, 0.1), (2.3, 1.6, 1.5), SKIN_DARK)
        for i in range(6):
            y = B["Chest"].y + 1.7 - i * 0.36
            spread = 1.25 - i * 0.07
            for sx in (-1, 1):
                for seg in range(3):
                    a0, a1 = seg * 0.42, (seg + 1) * 0.42
                    p0 = V3(sx * spread * math.sin(a0 + 0.35), y, -0.95 * math.cos(a0 + 0.35) + 0.15)
                    p1 = V3(sx * spread * math.sin(a1 + 0.35), y - 0.08, -0.95 * math.cos(a1 + 0.35) + 0.15)
                    self.tube("Chest", "Rib", p0, p1, 0.11, BONE, material="Slate")
        # abdominal wound (sutured, split open)
        self.blob("Pelvis", "Wound", B["Pelvis"] + V3(0.2, 0.55, -0.72), (1.5, 1.0, 0.5), MEAT_DARK, material="Granite")
        self.blob("Pelvis", "Wound", B["Pelvis"] + V3(0.25, 0.55, -0.8), (0.9, 0.55, 0.35), MEAT, material="Granite")
        for i in range(6):
            x = -0.45 + i * 0.18
            self.tube("Pelvis", "Suture", B["Pelvis"] + V3(x, 0.95, -0.92), B["Pelvis"] + V3(x + 0.08, 0.2, -0.92), 0.025, HAIR)
        # gown: torn panels, stained
        for i, (x, z, w, rot) in enumerate([(-0.9, -0.95, 1.1, 0.05), (0.2, -1.0, 1.0, -0.04), (1.0, -0.8, 0.7, 0.12),
                                           (-1.0, 0.95, 1.2, -0.06), (0.4, 1.0, 1.4, 0.03)]):
            h = 3.4 + 0.6 * math.sin(i)
            cf = CF(B["Chest"] + V3(x, 0.4 - h / 2 + 1.0, z)) * CF.angles(0, 0, rot)
            self.attach("Chest", "Gown", cf, (w, h, 0.08), self.sc.vary(GOWN if i % 2 else GOWN_DIRTY, 8), material="Fabric")
        for i in range(4):
            cf = CF(B["Pelvis"] + V3(-1.2 + i * 0.8, -1.3, 0.9 if i % 2 else -0.85)) * CF.angles(0, 0, sc.jitter(0.15))
            self.attach("Pelvis", "Gown", cf, (0.75, 2.2 + sc.jitter(0.5), 0.07), self.sc.vary(GOWN_DIRTY, 10), material="Fabric")
        for i in range(5):
            cf = CF(B["Chest"] + V3(sc.jitter(1.0), sc.jitter(1.2), -1.05 + sc.jitter(0.05)))
            self.attach("Chest", "Stain", cf, (0.5 + sc.rng.random() * 0.6, 0.4 + sc.rng.random() * 0.7, 0.03), BLOOD, material="Granite")
        # restraint straps + buckles (asylum)
        for y in (0.9, -0.2):
            self.attach("Chest", "Strap", CF(B["Chest"] + V3(0, y, 0)), (3.1, 0.32, 2.05), LEATHER, material="Fabric")
            self.attach("Chest", "Buckle", CF(B["Chest"] + V3(0.4, y, -1.05)), (0.42, 0.4, 0.08), STEEL, material="Metal")
        # neck
        self.limb("NeckB", "Flesh", B["Chest"] + V3(0, 2.3, -0.5), B["Head"] + V3(0, -0.2, 0.1), 0.42, 0.36, skin, segs=2)
        for i in range(3):
            self.tube("NeckB", "Vein", B["NeckB"] + V3(-0.3 + i * 0.3, -0.6, -0.3), B["NeckB"] + V3(-0.25 + i * 0.3, 0.6, -0.38), 0.035, BRUISE)
        # halo brace: ring around the skull, 4 rods to a shoulder vest
        ring_c = B["Head"] + V3(0, 0.65, 0.1)
        for i in range(14):
            a0, a1 = i * 2 * math.pi / 14, (i + 1) * 2 * math.pi / 14
            self.tube("Head", "Halo", ring_c + V3(math.cos(a0) * 1.05, 0, math.sin(a0) * 1.05),
                      ring_c + V3(math.cos(a1) * 1.05, 0, math.sin(a1) * 1.05), 0.07, RUST, material="CorrodedMetal")
        for a in (0.7, 2.45, 3.85, 5.6):
            top = ring_c + V3(math.cos(a) * 1.05, 0, math.sin(a) * 1.05)
            self.tube("Head", "Screw", top, top + V3(-math.cos(a) * 0.35, -0.1, -math.sin(a) * 0.35), 0.05, STEEL, material="Metal")
        for sx in (-1, 1):
            top = ring_c + V3(sx * 0.95, 0, 0.45)
            foot = B["Chest"] + V3(sx * 1.2, 1.9, -0.2)
            self.tube("Chest", "Rod", foot, foot + V3(0, 1.3, -0.4), 0.07, RUST, material="CorrodedMetal")
            self.tube("Head", "Rod", top, top + V3(0, -1.2, 0.3), 0.07, RUST, material="CorrodedMetal")
        # hospital wristband + IV line
        self.attach("LForeArm", "Band", CF(B["LForeArm"] + V3(0, -2.4, -0.1)), (0.6, 0.18, 0.6), (235, 235, 225), material="Plastic")
        iv = B["RForeArm"] + V3(0.2, 0.6, -0.4)
        self.tube("RForeArm", "Needle", iv, iv + V3(0.05, 0.5, -0.1), 0.03, STEEL, material="Metal")
        prev = iv
        for i in range(6):
            nxt = iv + V3(0.3 * math.sin(i * 0.9), -0.45 * (i + 1), -0.15 * i)
            self.tube("RForeArm", "IVTube", prev, nxt, 0.035, (200, 190, 170), transparency=0.3, material="Plastic")
            prev = nxt
        # pelvis chain + hook
        anchor = B["Pelvis"] + V3(1.2, -0.3, 0)
        prev = anchor
        for i in range(7):
            nxt = anchor + V3(0.25 * math.sin(i * 1.3), -0.42 * (i + 1), 0.2 * math.cos(i * 1.1))
            self.tube("Pelvis", "Chain", prev, nxt, 0.06, RUST, material="CorrodedMetal")
            prev = nxt
        self.tube("Pelvis", "Hook", prev, prev + V3(0.3, -0.5, 0), 0.07, STEEL, material="CorrodedMetal")
        self.tube("Pelvis", "Hook", prev + V3(0.3, -0.5, 0), prev + V3(0.05, -0.75, 0), 0.07, STEEL, material="CorrodedMetal")

        # arms: long, thin, veined, bruised
        for side, sx in (("L", -1), ("R", 1)):
            ua, fa, hd = B[side + "UpperArm"], B[side + "ForeArm"], B[side + "Hand"]
            self.blob("Chest", "Flesh", ua + V3(sx * 0.1, 0.1, 0), (1.1, 1.2, 1.1), skin)  # shoulder
            self.limb(side + "UpperArm", "Flesh", ua, fa, 0.38, 0.3, skin, segs=3)
            self.blob(side + "ForeArm", "Flesh", fa, (0.7, 0.75, 0.7), SKIN_DARK)  # elbow
            self.limb(side + "ForeArm", "Flesh", fa, hd, 0.3, 0.22, skin, segs=3)
            for i in range(4):
                t0, t1 = 0.15 + i * 0.2, 0.3 + i * 0.2
                self.tube(side + "ForeArm", "Vein", fa.lerp(hd, t0) + V3(sx * 0.3, 0, -0.1), fa.lerp(hd, t1) + V3(sx * 0.28, 0, -0.2), 0.03, BRUISE)
            self.blob(side + "UpperArm", "Bruise", ua.lerp(fa, 0.45) + V3(sx * 0.3, 0, -0.2), (0.6, 0.9, 0.5), BRUISE, transparency=0.35)
            # hand: palm + knuckles + 4 fingers (2 bones each) + claws
            self.attach(side + "Hand", "Palm", CF(hd + V3(0, -0.35, 0)), (0.55, 0.9, 0.95), skin)
            self.blob(side + "Hand", "Flesh", hd + V3(0, 0.05, 0), (0.6, 0.6, 0.8), SKIN_DARK)
            for i, fz in enumerate(FINGER_Z, 1):
                a, b = B["%sF%dA" % (side, i)], B["%sF%dB" % (side, i)]
                self.tube("%sF%dA" % (side, i), "Finger", a + V3(0, 0.15, 0), b + V3(0, 0.1, 0), 0.11, skin)
                self.blob("%sF%dA" % (side, i), "Knuckle", a + V3(0, 0.1, 0), (0.26, 0.26, 0.26), SKIN_DARK)
                self.tube("%sF%dB" % (side, i), "Finger", b + V3(0, 0.1, 0), b + V3(0, -0.75, 0), 0.095, skin)
                tip = b + V3(0, -0.75, 0)
                self.tube("%sF%dB" % (side, i), "Claw", tip, tip + V3(0, -0.85, -0.2), 0.055, HAIR, material="Slate")
            thumb = hd + V3(sx * 0.25, -0.3, -0.55)
            self.tube(side + "Hand", "Finger", thumb, thumb + V3(sx * 0.2, -0.55, -0.35), 0.11, skin)
            self.tube(side + "Hand", "Claw", thumb + V3(sx * 0.2, -0.55, -0.35), thumb + V3(sx * 0.3, -1.1, -0.6), 0.055, HAIR, material="Slate")

        # legs
        for side, sx in (("L", -1), ("R", 1)):
            th, sh, ft = B[side + "Thigh"], B[side + "Shin"], B[side + "Foot"]
            self.limb(side + "Thigh", "Flesh", th + V3(0, 0.2, 0), sh, 0.5, 0.36, skin, segs=3)
            self.blob(side + "Shin", "Flesh", sh, (0.8, 0.85, 0.8), SKIN_DARK)
            self.limb(side + "Shin", "Flesh", sh, ft + V3(0, 0.3, 0), 0.34, 0.26, skin, segs=3)
            self.blob(side + "Shin", "Bruise", sh.lerp(ft, 0.5) + V3(sx * 0.25, 0, -0.15), (0.5, 1.0, 0.4), BRUISE, transparency=0.4)
            self.attach(side + "Foot", "Foot", CF(ft + V3(0, -0.2, -0.3)), (0.75, 0.5, 1.6), SKIN_DARK)
            for i in range(4):
                self.blob(side + "Foot", "Toe", ft + V3(-0.27 + i * 0.18, -0.3, -1.2), (0.17, 0.17, 0.4), skin)
            if side == "R":
                self.attach("RShin", "Shackle", CF(sh.lerp(ft, 0.8)), (0.85, 0.3, 0.85), RUST, material="CorrodedMetal")
        # a rusty bone saw strapped to the left thigh
        saw = B["LThigh"] + V3(-0.55, -0.6, 0.2)
        self.attach("LThigh", "Saw", CF(saw) * CF.angles(0, 0, 0.3), (0.12, 2.2, 0.5), STEEL, material="CorrodedMetal")
        self.attach("LThigh", "SawHandle", CF(saw + V3(0.05, 1.3, 0)), (0.3, 0.6, 0.3), LEATHER, material="Wood")

    # -- head -------------------------------------------------------------------------
    def build_head(self):
        sc = self.sc
        H = V3(*BONES["Head"])
        J = V3(*BONES["Jaw"])
        skin = SKIN if self.variant == "Patient" else (168, 172, 162)
        # elongated skull, sunken temples, brow ridge
        self.blob("Head", "Skull", H + V3(0, 0.25, 0.05), (1.45, 2.05, 1.65), skin)
        self.blob("Head", "Brow", H + V3(0, 0.45, -0.55), (1.3, 0.45, 0.55), SKIN_DARK)
        for sx in (-1, 1):
            self.blob("Head", "Cheek", H + V3(sx * 0.5, -0.25, -0.5), (0.55, 0.7, 0.45), SKIN_DARK)
            # ear holes (larger on the blind variant)
            ear = (0.28, 0.42, 0.22) if self.variant == "Patient" else (0.42, 0.62, 0.3)
            self.blob("Head", "Ear", H + V3(sx * 0.72, 0.1, 0.1), ear, HAIR)
            if self.variant == "Blind":
                self.blob("Head", "EarFlesh", H + V3(sx * 0.78, 0.12, 0.1), (0.3, 0.75, 0.55), MEAT, material="Granite", transparency=0.1)
        self.blob("Head", "Nose", H + V3(0, 0.0, -0.78), (0.3, 0.45, 0.3), HAIR)  # cavity, no nose
        # eyes
        for sx in (-1, 1):
            socket = H + V3(sx * 0.33, 0.28, -0.62)
            self.blob("Head", "Socket", socket, (0.5, 0.42, 0.45), HAIR)
            if self.variant == "Patient":
                eye = self.blob("Head", "Eye", socket + V3(0, 0, -0.12), (0.26, 0.26, 0.26), (240, 230, 210), material="Neon")
                self.blob("Head", "Pupil", socket + V3(0, 0, -0.24), (0.1, 0.1, 0.08), HAIR)
                sc.pointlight(eye, (255, 40, 40), 5, 0.8, False)
            else:
                # sewn shut: coarse stitches across the socket
                for i in range(3):
                    x = socket.x - 0.16 + i * 0.16
                    self.tube("Head", "Stitch", V3(x, socket.y + 0.2, socket.z - 0.2), V3(x + 0.06, socket.y - 0.2, socket.z - 0.2), 0.03, HAIR)
                self.tube("Head", "Stitch", V3(socket.x - 0.25, socket.y, socket.z - 0.22), V3(socket.x + 0.25, socket.y + 0.02, socket.z - 0.22), 0.028, HAIR)
        # mouth / jaw
        self.blob("Head", "Mouth", H + V3(0, -0.5, -0.6), (0.95, 0.55, 0.6), HAIR)
        for i in range(8):
            x = -0.36 + i * 0.1
            cf = CF(H + V3(x, -0.42, -0.86)) * CF.angles(math.pi, 0, 0)
            self.attach("Head", "Tooth", cf, (0.08, 0.28 + (0.12 if i in (1, 6) else 0), 0.1), TOOTH, cls="WedgePart", material="Slate")
        self.blob("Jaw", "JawFlesh", J + V3(0, -0.15, -0.1), (1.0, 0.55, 1.1), skin)
        self.blob("Jaw", "Chin", J + V3(0, -0.2, -0.55), (0.6, 0.4, 0.5), SKIN_DARK)
        for i in range(8):
            x = -0.36 + i * 0.1
            self.attach("Jaw", "Tooth", CF(J + V3(x, 0.02, -0.55)), (0.08, 0.26 + (0.1 if i in (0, 7) else 0), 0.1), TOOTH, cls="WedgePart", material="Slate")
        # long tongue hanging out
        prev = J + V3(0.05, -0.05, -0.5)
        for i in range(5):
            nxt = J + V3(0.05 + 0.08 * math.sin(i), -0.1 - i * 0.28, -0.8 - i * 0.12)
            self.tube("Jaw", "Tongue", prev, nxt, 0.14 - i * 0.015, MEAT, material="Granite")
            prev = nxt
        drool = self.attach("Jaw", "Drool", CF(prev), (0.2, 0.2, 0.2), MEAT, transparency=1)
        self.sc.particles(drool, "Drip", "rbxasset://textures/particles/sparkles_main.dds", [(0, (90, 8, 10)), (1, (40, 4, 6))],
                          [(0, 0.12), (1, 0.05)], [(0, 0.2), (1, 1)], (0.6, 1.2), 4, (0.5, 1.5), spread=(10, 10),
                          acceleration=(0, -20, 0), direction="Bottom")
        # hair: long, greasy strands falling over the face and down the back
        for i in range(44):
            a = sc.rng.random() * math.pi * 2
            r = 0.55 + sc.rng.random() * 0.25
            top = H + V3(math.cos(a) * r, 0.9 + sc.rng.random() * 0.2, math.sin(a) * r * 0.9)
            length = 1.4 + sc.rng.random() * 1.6
            end = top + V3(math.cos(a) * 0.25 + sc.jitter(0.25), -length, math.sin(a) * 0.3 + sc.jitter(0.25))
            self.tube("Head", "Hair", top, end, 0.045, sc.vary(HAIR, 6), material="Fabric")
        if self.variant == "Blind":
            # bloodied bandage wrapped around the skull
            for i in range(5):
                y = 0.35 + i * 0.17
                cf = CF(H + V3(0, y, 0.0)) * CF.angles(0, sc.jitter(0.3), sc.jitter(0.08))
                self.attach("Head", "Bandage", cf, (1.62, 0.2, 1.8), sc.vary((205, 198, 180), 12), material="Fabric")
            self.attach("Head", "Bandage", CF(H + V3(0.3, 0.5, -0.86)), (0.6, 0.5, 0.05), BLOOD, material="Granite")
            tail = H + V3(0.8, 0.4, 0.5)
            self.tube("Head", "Bandage", tail, tail + V3(0.3, -1.6, 0.3), 0.08, (190, 182, 165), material="Fabric")
        # halo screws into the skull (visual stubs)
        for a in (0.7, 2.45, 3.85, 5.6):
            p = H + V3(math.cos(a) * 0.7, 0.65, math.sin(a) * 0.75 + 0.1)
            self.blob("Head", "Blood", p, (0.22, 0.2, 0.22), BLOOD, material="Granite")

    def build_effects(self):
        chest = self.bones["Chest"]
        aura = self.attach("Chest", "Aura", CF(V3(*BONES["Chest"]) + V3(0, 0.4, 0)), (1, 1, 1), HAIR, transparency=1)
        self.sc.particles(aura, "Ink", "rbxasset://textures/particles/smoke_main.dds", [(0, (10, 8, 8)), (1, (0, 0, 0))],
                          [(0, 1.2), (1, 3.5)], [(0, 1), (0.25, 0.75), (1, 1)], (1.5, 3), 5, (0.3, 1.0), spread=(60, 60),
                          acceleration=(0, 0.6, 0), z_offset=-0.5)
        feet = self.attach("Pelvis", "Dust", CF(V3(*BONES["Pelvis"]) + V3(0, -4.6, 0)), (1, 1, 1), HAIR, transparency=1)
        self.sc.particles(feet, "Dust", "rbxasset://textures/particles/smoke_main.dds", [(0, (60, 55, 50)), (1, (40, 38, 35))],
                          [(0, 0.6), (1, 2.2)], [(0, 0.7), (1, 1)], (0.8, 1.6), 0, (0.5, 1.5), spread=(80, 80), enabled=False)
        self.sc.pointlight(chest, (120, 0, 0), 9, 0.0, False, name="Rage")

    def build(self):
        self.build_skeleton()
        self.build_body()
        self.build_head()
        self.build_effects()
        return self.model


def build_monster(scene, parent, name="Monster", variant="Patient"):
    return MonsterBuilder(scene, parent, name, variant).build()
