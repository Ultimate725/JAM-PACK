#!/usr/bin/env python3
"""Store art for Creator Hub: game icon (512), thumbnail (1920x1080) and one 512x512 icon per
game pass / developer product. The monster silhouette is rendered from the real game model.

    python3 tools/make_store_art.py [out_dir]     (default: palata13/assets/store)
"""
import math
import os
import random
import sys
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)
from buildkit import rbxml as X  # noqa: E402
from buildkit import render  # noqa: E402
from buildkit.kit import Scene  # noqa: E402
from gen.monster import build_monster  # noqa: E402

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
FONT_SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
if not os.path.exists(FONT_SANS):
    FONT_SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
RED = (200, 24, 24)

PASSES = [
    ("PremiumPass", "pass", "ПРЕМИУМ", "БАТЛПАСС", (170, 20, 30), "drop"),
    ("VIP", "pass", "VIP", "x2 МОНЕТ", (200, 160, 40), "crown"),
    ("BigBattery", "pass", "ВЕЧНАЯ", "БАТАРЕЯ", (60, 170, 80), "battery"),
    ("Coins100", "product", "100", "МОНЕТ", (200, 160, 40), "coin"),
    ("Coins500", "product", "500", "МОНЕТ", (210, 170, 50), "coins"),
    ("Coins1500", "product", "1500", "МОНЕТ", (230, 190, 60), "chest"),
    ("SkipTier", "product", "+1", "УРОВЕНЬ", (180, 40, 40), "skip"),
    ("Revive", "product", "ЖЕТОН", "ВОЗРОЖДЕНИЯ", (90, 200, 110), "cross"),
]


def font(path, size):
    return ImageFont.truetype(path, size)


def grime(img, seed, amount=0.18):
    r = random.Random(seed)
    w, h = img.size
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(int(w * h / 900)):  # film grain
        x, y = r.randrange(w), r.randrange(h)
        v = r.randrange(0, 255)
        d.point((x, y), fill=(v, v, v, int(255 * amount)))
    for _ in range(6):  # scratches
        x = r.randrange(w)
        d.line([(x, 0), (x + r.randrange(-20, 20), h)], fill=(230, 220, 210, 40), width=1)
    return Image.alpha_composite(img.convert("RGBA"), layer)


def vignette(img, strength=0.85):
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    for i in range(40):
        k = i / 40
        d.ellipse([w * (0.5 - 0.75 + 0.5 * k), h * (0.5 - 0.75 + 0.5 * k), w * (0.5 + 0.75 - 0.5 * k), h * (0.5 + 0.75 - 0.5 * k)],
                  fill=int(255 * k))
    mask = mask.filter(ImageFilter.GaussianBlur(min(w, h) / 10))
    dark = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    inv = mask.point(lambda v: int((255 - v) * strength))
    return Image.composite(dark, img.convert("RGBA"), inv)


def background(size, tint, seed):
    w, h = size
    img = Image.new("RGBA", size, (8, 6, 6, 255))
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.ellipse([w * 0.1, h * 0.05, w * 0.9, h * 0.95], fill=tint + (150,))
    glow = glow.filter(ImageFilter.GaussianBlur(min(w, h) / 5))
    img = Image.alpha_composite(img, glow)
    # blood drips from the top
    r = random.Random(seed)
    d = ImageDraw.Draw(img)
    for _ in range(int(w / 40)):
        x = r.randrange(w)
        ln = r.randrange(int(h * 0.05), int(h * 0.35))
        wd = r.randrange(3, max(4, w // 60))
        d.rectangle([x, 0, x + wd, ln], fill=(90, 6, 8, 255))
        d.ellipse([x - wd * 0.3, ln - wd, x + wd * 1.3, ln + wd * 0.8], fill=(90, 6, 8, 255))
    return img


def monster_silhouette(height):
    doc = X.Doc()
    sc = Scene(doc, seed=7)
    root = ET.Element("roblox")
    m = build_monster(sc, root, "M", "Patient")
    path = "/tmp/_palata13_monster.png"
    render.sideview(m, path, axis="z", scale=60)
    sil = Image.open(path).convert("RGBA")
    px = sil.load()
    w, h = sil.size
    bg = px[0, 0]
    for y in range(h):
        for x in range(w):
            r_, g_, b_, _ = px[x, y]
            if (r_, g_, b_) == bg[:3]:
                px[x, y] = (0, 0, 0, 0)
            else:
                lum = (r_ + g_ + b_) / 3
                px[x, y] = (int(lum * 0.18), 0, 0, 255)  # near-black body with a red undertone
    s = height / h
    return sil.resize((max(1, int(w * s)), height), Image.LANCZOS)


def glow_eyes(img, centers, r):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for cx, cy in centers:
        d.ellipse([cx - r * 3, cy - r * 3, cx + r * 3, cy + r * 3], fill=(255, 30, 30, 90))
    layer = layer.filter(ImageFilter.GaussianBlur(r * 1.5))
    d = ImageDraw.Draw(layer)
    for cx, cy in centers:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 235, 220, 255))
    return Image.alpha_composite(img, layer)


def title(img, text, xy, size, anchor="mm", color=(235, 225, 215)):
    d = ImageDraw.Draw(img)
    f = font(FONT_BOLD, size)
    x, y = xy
    d.text((x + size * 0.04, y + size * 0.02), text, font=f, fill=(255, 20, 20, 160), anchor=anchor)  # chromatic shift
    d.text((x - size * 0.04, y), text, font=f, fill=(60, 220, 255, 90), anchor=anchor)
    d.text((x, y), text, font=f, fill=color + (255,), anchor=anchor, stroke_width=max(2, size // 30), stroke_fill=(0, 0, 0, 255))


def symbol(d, kind, cx, cy, s, color):
    c = color + (255,)
    dark = (20, 10, 10, 255)
    if kind == "drop":
        d.polygon([(cx, cy - s), (cx - s * 0.6, cy + s * 0.2), (cx + s * 0.6, cy + s * 0.2)], fill=c)
        d.ellipse([cx - s * 0.62, cy - s * 0.25, cx + s * 0.62, cy + s * 0.9], fill=c)
    elif kind == "crown":
        pts = [(cx - s, cy + s * 0.5), (cx - s, cy - s * 0.4), (cx - s * 0.5, cy + s * 0.05), (cx, cy - s * 0.7),
               (cx + s * 0.5, cy + s * 0.05), (cx + s, cy - s * 0.4), (cx + s, cy + s * 0.5)]
        d.polygon(pts, fill=c)
        for k in (-0.5, 0, 0.5):
            d.ellipse([cx + k * s - s * 0.1, cy + s * 0.15, cx + k * s + s * 0.1, cy + s * 0.35], fill=(160, 20, 20, 255))
    elif kind == "battery":
        d.rounded_rectangle([cx - s * 0.5, cy - s * 0.85, cx + s * 0.5, cy + s * 0.9], radius=s * 0.12, outline=c, width=int(s * 0.12))
        d.rectangle([cx - s * 0.2, cy - s * 1.05, cx + s * 0.2, cy - s * 0.85], fill=c)
        for k in range(4):
            d.rectangle([cx - s * 0.32, cy + s * 0.4 - k * s * 0.4, cx + s * 0.32, cy + s * 0.65 - k * s * 0.4], fill=c)
    elif kind in ("coin", "coins", "chest"):
        n = {"coin": 1, "coins": 3, "chest": 6}[kind]
        for k in range(n):
            ox = (k % 3 - (min(n, 3) - 1) / 2) * s * 0.55
            oy = -(k // 3) * s * 0.45 + (s * 0.2 if n > 1 else 0)
            rr = s * (0.75 if n == 1 else 0.48)
            d.ellipse([cx + ox - rr, cy + oy - rr, cx + ox + rr, cy + oy + rr], fill=c, outline=(120, 80, 20, 255), width=max(2, int(rr * 0.12)))
            if k == n - 1:  # only the top coin is fully visible
                d.text((cx + ox, cy + oy), "13", font=font(FONT_SANS, int(rr * 0.9)), fill=(120, 80, 20, 255), anchor="mm")
    elif kind == "skip":
        for k in (-0.45, 0.35):
            d.polygon([(cx + k * s - s * 0.4, cy - s * 0.6), (cx + k * s + s * 0.4, cy), (cx + k * s - s * 0.4, cy + s * 0.6)], fill=c)
    elif kind == "cross":
        d.rectangle([cx - s * 0.22, cy - s * 0.8, cx + s * 0.22, cy + s * 0.8], fill=c)
        d.rectangle([cx - s * 0.8, cy - s * 0.22, cx + s * 0.8, cy + s * 0.22], fill=c)
    _ = dark


def make_icon(out, sil):
    img = background((512, 512), (150, 0, 0), 1)
    s = sil.resize((int(sil.width * 470 / sil.height), 470), Image.LANCZOS)
    img.alpha_composite(s, (256 - s.width // 2, 70))
    head_y = 70 + int(470 * 0.12)
    img = glow_eyes(img, [(256 - 14, head_y), (256 + 14, head_y)], 5)
    title(img, "ПАЛАТА", (256, 392), 60)
    title(img, "13", (256, 462), 66, color=(235, 40, 40))
    img = grime(vignette(img, 0.8), 2)
    img.convert("RGB").save(os.path.join(out, "GameIcon_512.png"))


def make_thumbnail(out, sil):
    w, h = 1920, 1080
    img = background((w, h), (120, 0, 0), 3)
    d = ImageDraw.Draw(img)
    # receding corridor lines
    for k in range(14):
        t = k / 14
        x0, x1 = w * 0.76 - w * 0.4 * (1 - t), w * 0.76 + w * 0.4 * (1 - t)
        y0, y1 = h * 0.5 - h * 0.45 * (1 - t), h * 0.5 + h * 0.45 * (1 - t)
        d.rectangle([x0, y0, x1, y1], outline=(60, 20, 20, int(140 * (1 - t))), width=2)
    s = sil.resize((int(sil.width * 900 / sil.height), 900), Image.LANCZOS)
    img.alpha_composite(s, (int(w * 0.76) - s.width // 2, 120))
    head_y = 120 + int(900 * 0.12)
    img = glow_eyes(img, [(int(w * 0.76) - 26, head_y), (int(w * 0.76) + 26, head_y)], 9)
    # flashlight cone from the left
    cone = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(cone).polygon([(0, h * 0.62), (w * 0.86, h * 0.2), (w * 0.86, h * 0.98)], fill=(255, 236, 205, 46))
    img = Image.alpha_composite(img, cone.filter(ImageFilter.GaussianBlur(40)))
    title(img, "ПАЛАТА 13", (80, 300), 190, anchor="lm")
    d = ImageDraw.Draw(img)
    d.text((90, 430), "3 КАРТЫ · 4 СЛОЖНОСТИ · ОНО СЛЫШИТ ТЕБЯ", font=font(FONT_SANS, 46), fill=(220, 60, 60, 255), anchor="lm")
    d.text((90, 960), "REC ● КАМ-13  03:13:00", font=font(FONT_SANS, 40), fill=(235, 225, 215, 220), anchor="lm")
    img = grime(vignette(img, 0.75), 4, 0.12)
    img.convert("RGB").save(os.path.join(out, "Thumbnail_1920x1080.png"))


def make_pass_icons(out):
    for i, (key, kind, top, bottom, color, sym) in enumerate(PASSES):
        img = background((512, 512), tuple(int(c * 0.6) for c in color), 10 + i)
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([18, 18, 494, 494], radius=36, outline=color + (255,), width=6)
        symbol(d, sym, 256, 210, 120, color)
        title(img, top, (256, 380), 72 if len(top) <= 6 else 58)
        d = ImageDraw.Draw(img)
        d.text((256, 448), bottom, font=font(FONT_SANS, 36 if len(bottom) <= 10 else 28), fill=color + (255,), anchor="mm")
        img = grime(vignette(img, 0.6), 20 + i, 0.1)
        sub = "GamePass" if kind == "pass" else "Product"
        img.convert("RGB").save(os.path.join(out, "%s_%s_512.png" % (sub, key)))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "assets", "store")
    os.makedirs(out, exist_ok=True)
    sil = monster_silhouette(1200)
    make_icon(out, sil)
    make_thumbnail(out, sil)
    make_pass_icons(out)
    for f in sorted(os.listdir(out)):
        print(f, "%.0f KB" % (os.path.getsize(os.path.join(out, f)) / 1024))


if __name__ == "__main__":
    main()
