"""rbxlx (Roblox XML place) element builders on top of xml.etree.ElementTree."""
import xml.etree.ElementTree as ET
from .cframe import CF, V3

# Enum tokens -------------------------------------------------------------
MAT = {
    "Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512, "WoodPlanks": 528,
    "Marble": 784, "Basalt": 788, "Slate": 800, "CrackedLava": 804, "Concrete": 816,
    "Limestone": 820, "Granite": 832, "Pavement": 836, "Brick": 848, "Pebble": 864,
    "Cobblestone": 880, "Rock": 896, "Sandstone": 912, "CorrodedMetal": 1040,
    "DiamondPlate": 1056, "Foil": 1072, "Metal": 1088, "Grass": 1280, "LeafyGrass": 1284,
    "Sand": 1296, "Fabric": 1312, "Snow": 1328, "Mud": 1344, "Ground": 1360,
    "Asphalt": 1376, "Salt": 1392, "Ice": 1536, "Glass": 1568, "ForceField": 1584,
}
FACE = {"Right": 0, "Top": 1, "Back": 2, "Left": 3, "Bottom": 4, "Front": 5}
MESH = {"Head": 0, "Torso": 1, "Wedge": 2, "Sphere": 3, "Cylinder": 4, "FileMesh": 5, "Brick": 6,
        "Prism": 7, "Pyramid": 8, "ParallelRamp": 9, "RightAngleRamp": 10, "CornerWedge": 11}
SHAPE = {"Ball": 0, "Block": 1, "Cylinder": 2, "Wedge": 3, "CornerWedge": 4}


class Doc:
    """Referent allocator shared by every generated element."""

    def __init__(self, start=0x01000000):
        self.counter = start

    def ref(self):
        self.counter += 1
        return "RBX%08X" % self.counter


def _sub(parent, tag, name, text=None):
    e = ET.SubElement(parent, tag)
    e.set("name", name)
    if text is not None:
        e.text = text
    return e


def fmt(v):
    v = float(v)
    if abs(v - round(v)) < 1e-9:
        return str(int(round(v)))
    return ("%.5f" % v).rstrip("0").rstrip(".")


def prop_string(props, name, value):
    _sub(props, "string", name, str(value))


def prop_protected(props, name, value):
    _sub(props, "ProtectedString", name, value)


def prop_bool(props, name, value):
    _sub(props, "bool", name, "true" if value else "false")


def prop_float(props, name, value):
    _sub(props, "float", name, fmt(value))


def prop_int(props, name, value):
    _sub(props, "int", name, str(int(value)))


def prop_token(props, name, value):
    _sub(props, "token", name, str(int(value)))


def prop_color3uint8(props, name, rgb):
    r, g, b = [max(0, min(255, int(round(c)))) for c in rgb]
    _sub(props, "Color3uint8", name, str(0xFF000000 | (r << 16) | (g << 8) | b))


def prop_color3(props, name, rgb):
    e = _sub(props, "Color3", name)
    for tag, c in zip("RGB", rgb):
        ET.SubElement(e, tag).text = fmt(c / 255.0)


def prop_vector3(props, name, v):
    e = _sub(props, "Vector3", name)
    for tag, c in zip("XYZ", v):
        ET.SubElement(e, tag).text = fmt(c)


def prop_vector2(props, name, v):
    e = _sub(props, "Vector2", name)
    for tag, c in zip("XY", v):
        ET.SubElement(e, tag).text = fmt(c)


def prop_cframe(props, name, cf):
    e = _sub(props, "CoordinateFrame", name)
    for tag, c in zip("XYZ", cf.p):
        ET.SubElement(e, tag).text = fmt(c)
    for i, tag in enumerate(["R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]):
        ET.SubElement(e, tag).text = fmt(cf.r[i])


def prop_ref(props, name, referent):
    _sub(props, "Ref", name, referent or "null")


def prop_content(props, name, url):
    e = _sub(props, "Content", name)
    ET.SubElement(e, "url").text = url


def prop_numseq(props, name, keypoints):
    # keypoints: list of (time, value[, envelope])
    parts = []
    for kp in keypoints:
        t, v = kp[0], kp[1]
        env = kp[2] if len(kp) > 2 else 0
        parts.append("%s %s %s" % (fmt(t), fmt(v), fmt(env)))
    _sub(props, "NumberSequence", name, " ".join(parts) + " ")


def prop_colorseq(props, name, keypoints):
    # keypoints: list of (time, (r,g,b)) with rgb in 0..255
    parts = []
    for t, rgb in keypoints:
        parts.append("%s %s %s %s 0" % (fmt(t), fmt(rgb[0] / 255.0), fmt(rgb[1] / 255.0), fmt(rgb[2] / 255.0)))
    _sub(props, "ColorSequence", name, " ".join(parts) + " ")


def prop_numrange(props, name, lo, hi=None):
    if hi is None:
        hi = lo
    _sub(props, "NumberRange", name, "%s %s " % (fmt(lo), fmt(hi)))


ENCODERS = {
    "string": prop_string, "ProtectedString": prop_protected, "bool": prop_bool, "float": prop_float,
    "int": prop_int, "token": prop_token, "Color3uint8": prop_color3uint8, "Color3": prop_color3,
    "Vector3": prop_vector3, "Vector2": prop_vector2, "CoordinateFrame": prop_cframe, "Ref": prop_ref,
    "Content": prop_content, "NumberSequence": prop_numseq, "ColorSequence": prop_colorseq,
}


def item(doc, cls, name, props=None, parent=None):
    """Create an <Item>. props is a list of (type, name, value) tuples."""
    e = ET.Element("Item") if parent is None else ET.SubElement(parent, "Item")
    e.set("class", cls)
    e.set("referent", doc.ref())
    p = ET.SubElement(e, "Properties")
    prop_string(p, "Name", name)
    for entry in props or []:
        typ, pname, value = entry[0], entry[1], entry[2]
        if typ == "NumberRange":
            prop_numrange(p, pname, *value)
        else:
            ENCODERS[typ](p, pname, value)
    return e


def props_of(elem):
    return elem.find("Properties")


def set_prop(elem, typ, name, value):
    """Replace or add a property on an existing <Item>."""
    p = props_of(elem)
    for c in list(p):
        if c.get("name") == name:
            p.remove(c)
    if typ == "NumberRange":
        prop_numrange(p, name, *value)
    else:
        ENCODERS[typ](p, name, value)


def get_prop(elem, name):
    p = props_of(elem)
    if p is None:
        return None
    for c in p:
        if c.get("name") == name:
            return c
    return None


def get_name(elem):
    n = get_prop(elem, "Name")
    return n.text if n is not None else None


def get_cframe(elem):
    c = get_prop(elem, "CFrame")
    if c is None:
        return None
    pos = [float(c.find(t).text) for t in "XYZ"]
    rot = [float(c.find(t).text) for t in ["R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]]
    return CF(pos, rot)


def get_size(elem):
    s = get_prop(elem, "size")
    if s is None:
        return None
    return V3(*[float(s.find(t).text) for t in "XYZ"])


def child(elem, name, cls=None):
    for c in elem.findall("Item"):
        if get_name(c) == name and (cls is None or c.get("class") == cls):
            return c
    return None


def path(root, dotted):
    cur = root
    for seg in dotted.split("/"):
        nxt = None
        for c in cur.findall("Item"):
            if get_name(c) == seg:
                nxt = c
                break
        if nxt is None:
            return None
        cur = nxt
    return cur


def service(root, cls, name=None):
    for c in root.findall("Item"):
        if c.get("class") == cls:
            return c
    return item(Doc(0x00F00000 + hash(cls) % 1000), cls, name or cls, parent=root)


def write(root, filename):
    tree = ET.ElementTree(root)
    ET.indent(tree, space="  ")
    tree.write(filename, encoding="utf-8", xml_declaration=False)


def load(filename):
    return ET.parse(filename).getroot()


def max_referent(root):
    best = 0
    for e in root.iter("Item"):
        r = e.get("referent", "")
        if r.startswith("RBX"):
            try:
                best = max(best, int(r[3:], 16))
            except ValueError:
                pass
    return best
