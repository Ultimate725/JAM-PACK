"""Verification renders: top-down footprint map and orthographic side views (PIL)."""
import math
from PIL import Image, ImageDraw
from . import rbxml as X


def _corners(cf, size):
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                pts.append(cf.point((sx * hx, sy * hy, sz * hz)))
    return pts


def collect(elem, pred=None):
    out = []
    for e in elem.iter("Item"):
        if e.get("class") in ("Part", "WedgePart", "SpawnLocation", "MeshPart", "CornerWedgePart"):
            cf, size = X.get_cframe(e), X.get_size(e)
            if cf is None or size is None:
                continue
            if pred and not pred(e):
                continue
            out.append((e, cf, size))
    return out


def _color_of(e):
    c = X.get_prop(e, "Color3uint8")
    if c is None:
        return (200, 200, 200)
    v = int(c.text)
    return ((v >> 16) & 255, (v >> 8) & 255, v & 255)


def topdown(elem, filename, scale=3, pred=None, y_range=None, highlight=None, labels=None):
    """Draw every part's XZ footprint; higher parts drawn later (painter), ceilings skipped via y_range."""
    parts = collect(elem, pred)
    if not parts:
        raise RuntimeError("nothing to render")
    pts_all = []
    for e, cf, size in parts:
        pts_all.extend(_corners(cf, size))
    minx = min(p.x for p in pts_all) - 4
    maxx = max(p.x for p in pts_all) + 4
    minz = min(p.z for p in pts_all) - 4
    maxz = max(p.z for p in pts_all) + 4
    w, h = int((maxx - minx) * scale), int((maxz - minz) * scale)
    img = Image.new("RGB", (max(w, 1), max(h, 1)), (18, 18, 18))
    d = ImageDraw.Draw(img)
    parts.sort(key=lambda t: t[1].p.y - t[2][1] / 2)  # low first
    for e, cf, size in parts:
        if y_range and not (y_range[0] <= cf.p.y <= y_range[1]):
            continue
        tr = X.get_prop(e, "Transparency")
        if tr is not None and float(tr.text) >= 1 and not (highlight and highlight(e)):
            continue
        cs = _corners(cf, size)
        poly = [((p.x - minx) * scale, (p.z - minz) * scale) for p in cs]
        # convex hull of the footprint
        hull = _hull(poly)
        col = _color_of(e)
        if highlight and highlight(e):
            col = (255, 0, 255)
        d.polygon(hull, fill=col, outline=tuple(max(0, c - 40) for c in col))
    for (x, z, text) in labels or []:
        d.text(((x - minx) * scale, (z - minz) * scale), text, fill=(255, 255, 0))
    img.save(filename)
    return filename, (minx, minz, scale)


def sideview(elem, filename, axis="x", scale=20, pred=None):
    """Orthographic projection onto the plane perpendicular to `axis` (x: view from +X, looks at YZ)."""
    parts = collect(elem, pred)
    pts_all = []
    for e, cf, size in parts:
        pts_all.extend(_corners(cf, size))
    if axis == "x":
        proj = lambda p: (p.z, p.y)
    elif axis == "z":
        proj = lambda p: (p.x, p.y)
    else:
        proj = lambda p: (p.x, p.z)
    us = [proj(p)[0] for p in pts_all]
    vs = [proj(p)[1] for p in pts_all]
    minu, maxu, minv, maxv = min(us) - 1, max(us) + 1, min(vs) - 1, max(vs) + 1
    w, h = int((maxu - minu) * scale), int((maxv - minv) * scale)
    img = Image.new("RGB", (max(w, 1), max(h, 1)), (20, 20, 24))
    d = ImageDraw.Draw(img)
    depth = {"x": lambda cf: cf.p.x, "z": lambda cf: -cf.p.z, "y": lambda cf: cf.p.y}[axis]
    parts.sort(key=lambda t: depth(t[1]))
    for e, cf, size in parts:
        tr = X.get_prop(e, "Transparency")
        if tr is not None and float(tr.text) >= 1:
            continue
        cs = [proj(p) for p in _corners(cf, size)]
        poly = [((u - minu) * scale, h - (v - minv) * scale) for u, v in cs]
        hull = _hull(poly)
        col = _color_of(e)
        d.polygon(hull, fill=col, outline=tuple(max(0, c - 30) for c in col))
    img.save(filename)
    return filename


def _hull(points):
    pts = sorted(set(points))
    if len(pts) <= 2:
        return pts
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower = []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper = []
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]
