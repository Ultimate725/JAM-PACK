"""Scene helper: builds Roblox instances (parts, meshes, lights, joints) into an ElementTree."""
import math
import random
from .cframe import CF, V3
from . import rbxml as X

RUSTY = (96, 70, 52)
WHITE = (222, 218, 205)
BLACK = (14, 12, 12)


class Scene:
    def __init__(self, doc, seed=13):
        self.doc = doc
        self.rng = random.Random(seed)
        self.count = 0

    # containers ----------------------------------------------------------
    def folder(self, parent, name):
        return X.item(self.doc, "Folder", name, parent=parent)

    def model(self, parent, name):
        return X.item(self.doc, "Model", name, parent=parent)

    # parts ---------------------------------------------------------------
    def part(self, parent, name, cf, size, color, material="SmoothPlastic", transparency=0.0, reflectance=0.0,
             anchored=True, collide=True, shape=None, cast_shadow=True, can_query=True, can_touch=False,
             massless=False, cls="Part"):
        if not isinstance(cf, CF):
            cf = CF(cf)
        props = [
            ("bool", "Anchored", anchored), ("bool", "CanCollide", collide), ("bool", "CanTouch", can_touch),
            ("bool", "CanQuery", can_query), ("CoordinateFrame", "CFrame", cf), ("Vector3", "size", size),
            ("Color3uint8", "Color3uint8", color), ("token", "Material", X.MAT[material]),
            ("float", "Transparency", transparency), ("float", "Reflectance", reflectance),
            ("bool", "CastShadow", cast_shadow), ("token", "TopSurface", 0), ("token", "BottomSurface", 0),
            ("bool", "Massless", massless),
        ]
        if shape:
            props.append(("token", "shape", X.SHAPE[shape]))
        self.count += 1
        return X.item(self.doc, cls, name, props, parent=parent)

    box = part

    def ball(self, parent, name, pos, diameter, color, **kw):
        return self.part(parent, name, CF(pos), (diameter, diameter, diameter), color, shape="Ball", **kw)

    def ellipsoid(self, parent, name, cf, size, color, **kw):
        """Sphere mesh stretched to size (part size is the bounding box)."""
        p = self.part(parent, name, cf, size, color, **kw)
        self.mesh(p, "Sphere")
        return p

    def cyl(self, parent, name, a, b, radius, color, **kw):
        """Cylinder part whose axis (X) runs from point a to point b."""
        a, b = V3(*a), V3(*b)
        d = b - a
        length = d.mag
        mid = a + d * 0.5
        # part X axis must align with d
        look = CF.lookat(mid, mid + d) if length > 1e-6 else CF(mid)
        cf = look * CF.rot_y(math.pi / 2)  # rotate so X axis points along -Z (look)
        return self.part(parent, name, cf, (length, radius * 2, radius * 2), color, shape="Cylinder", **kw)

    def wedge(self, parent, name, cf, size, color, **kw):
        kw.setdefault("cls", "WedgePart")
        return self.part(parent, name, cf, size, color, **kw)

    # attachments to parts ---------------------------------------------------
    def mesh(self, part, meshtype, scale=(1, 1, 1), offset=None):
        props = [("token", "MeshType", X.MESH[meshtype]), ("Vector3", "Scale", scale)]
        if offset:
            props.append(("Vector3", "Offset", offset))
        return X.item(self.doc, "SpecialMesh", "Mesh", props, parent=part)

    def pointlight(self, part, color, range_, brightness, shadows=False, name="PointLight"):
        return X.item(self.doc, "PointLight", name, [
            ("float", "Brightness", brightness), ("float", "Range", range_), ("Color3", "Color", color),
            ("bool", "Shadows", shadows)], parent=part)

    def spotlight(self, part, face, angle, range_, brightness, color, shadows=True, name="SpotLight"):
        return X.item(self.doc, "SpotLight", name, [
            ("token", "Face", X.FACE[face]), ("float", "Angle", angle), ("float", "Range", range_),
            ("float", "Brightness", brightness), ("Color3", "Color", color), ("bool", "Shadows", shadows)], parent=part)

    def surfacelight(self, part, face, angle, range_, brightness, color, name="SurfaceLight"):
        return X.item(self.doc, "SurfaceLight", name, [
            ("token", "Face", X.FACE[face]), ("float", "Brightness", brightness), ("float", "Range", range_),
            ("float", "Angle", angle), ("Color3", "Color", color)], parent=part)

    def strval(self, parent, name, value):
        return X.item(self.doc, "StringValue", name, [("string", "Value", value)], parent=parent)

    def numval(self, parent, name, value):
        return X.item(self.doc, "NumberValue", name, [("float", "Value", value)], parent=parent)

    def boolval(self, parent, name, value):
        return X.item(self.doc, "BoolValue", name, [("bool", "Value", value)], parent=parent)

    def sign(self, part, text, style="plain"):
        self.strval(part, "SignText", text)
        self.strval(part, "SignStyle", style)
        return part

    def attachment(self, part, name, cf):
        return X.item(self.doc, "Attachment", name, [("CoordinateFrame", "CFrame", cf)], parent=part)

    def weld(self, part0, part1, c0, c1=None, name="W"):
        """Weld parented to part1; c0 = part1 frame expressed in part0 space."""
        return X.item(self.doc, "Weld", name, [
            ("Ref", "Part0", part0.get("referent")), ("Ref", "Part1", part1.get("referent")),
            ("CoordinateFrame", "C0", c0), ("CoordinateFrame", "C1", c1 or CF())], parent=part1)

    def motor6d(self, holder, name, part0, part1, c0, c1=None):
        return X.item(self.doc, "Motor6D", name, [
            ("Ref", "Part0", part0.get("referent")), ("Ref", "Part1", part1.get("referent")),
            ("CoordinateFrame", "C0", c0), ("CoordinateFrame", "C1", c1 or CF())], parent=holder)

    def humanoid(self, model, walkspeed=9, hipheight=2.5, health=100):
        return X.item(self.doc, "Humanoid", "Humanoid", [
            ("float", "HipHeight", hipheight), ("float", "WalkSpeed", walkspeed), ("token", "RigType", 1),
            ("token", "DisplayDistanceType", 2), ("token", "HealthDisplayType", 2), ("bool", "RequiresNeck", False),
            ("bool", "BreakJointsOnDeath", False), ("bool", "AutoJumpEnabled", False),
            ("float", "MaxHealth", health), ("float", "Health", health)], parent=model)

    def particles(self, part, name, texture, color, size, transparency, lifetime, rate, speed, spread=(25, 25),
                  light_emission=0.0, acceleration=(0, 0, 0), rot_speed=(-30, 30), rotation=(0, 360), drag=0.0,
                  enabled=True, z_offset=0.0, direction="Top"):
        return X.item(self.doc, "ParticleEmitter", name, [
            ("Content", "Texture", texture), ("ColorSequence", "Color", color), ("NumberSequence", "Size", size),
            ("NumberSequence", "Transparency", transparency), ("NumberRange", "Lifetime", lifetime),
            ("float", "Rate", rate), ("NumberRange", "Speed", speed), ("Vector2", "SpreadAngle", spread),
            ("float", "LightEmission", light_emission), ("Vector3", "Acceleration", acceleration),
            ("NumberRange", "RotSpeed", rot_speed), ("NumberRange", "Rotation", rotation), ("float", "Drag", drag),
            ("bool", "Enabled", enabled), ("float", "ZOffset", z_offset), ("token", "EmissionDirection", X.FACE[direction]),
            ("float", "LightInfluence", 0.4)], parent=part)

    def smoke(self, part, color=(30, 28, 28), rate=6, size=(2, 5), lifetime=(2, 4), speed=(0.5, 1.5), transparency=0.6):
        return self.particles(part, "Smoke", "rbxasset://textures/particles/smoke_main.dds", [(0, color), (1, color)],
                              [(0, size[0]), (1, size[1])], [(0, 1), (0.2, transparency), (1, 1)], lifetime, rate, speed,
                              spread=(40, 40), acceleration=(0, 0.4, 0))

    def sparks(self, part, color=(255, 200, 120), rate=10):
        return self.particles(part, "Sparks", "rbxasset://textures/particles/sparkles_main.dds", [(0, color), (1, (255, 80, 20))],
                              [(0, 0.5), (1, 0.1)], [(0, 0), (1, 1)], (0.4, 0.9), rate, (6, 14), spread=(60, 60),
                              light_emission=1.0, acceleration=(0, -30, 0))

    def spawn_location(self, parent, cf, size=(12, 1, 12)):
        p = self.part(parent, "SpawnLocation", cf, size, (60, 60, 60), transparency=1, cast_shadow=False, cls="SpawnLocation")
        X.prop_bool(X.props_of(p), "Neutral", True)
        X.prop_int(X.props_of(p), "Duration", 0)
        return p

    # random helpers ---------------------------------------------------------
    def jitter(self, amt):
        return (self.rng.random() * 2 - 1) * amt

    def chance(self, p):
        return self.rng.random() < p

    def pick(self, seq):
        return seq[self.rng.randrange(len(seq))]

    def vary(self, color, amt=10):
        return tuple(max(0, min(255, c + self.rng.randint(-amt, amt))) for c in color)
