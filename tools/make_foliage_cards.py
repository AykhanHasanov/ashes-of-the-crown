"""Dev tool: composes foliage cards (RGBA textures) from ambientCG leaf and grass atlases.

Single photographed leaves are cut out of the atlases (connected components of the
opacity map) and arranged on twigs the way SpeedTree-style cluster cards are made:
the tree generator (tools/gen_trees.gd) then puts these cards on its branches.

Sources (CC0, ambientCG, 1K-JPG): LeafSet014/016/019/024/027, Foliage001/003/006.
Usage: python tools/make_foliage_cards.py <folder with the unzipped ambientCG sets>
Output: assets/foliage/cards/*.png
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
from scipy import ndimage

SRC = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "foliage", "cards")


def pieces(set_id, stem="bottom", min_area=4000):
    """Cuts every leaf (or blade) out of an atlas; returns RGBA images with the stem at the bottom."""
    col = Image.open(os.path.join(SRC, set_id, f"{set_id}_1K-JPG_Color.jpg")).convert("RGB")
    opa = Image.open(os.path.join(SRC, set_id, f"{set_id}_1K-JPG_Opacity.jpg")).convert("L")
    mask = np.array(opa) > 40
    labels, n = ndimage.label(ndimage.binary_closing(mask, iterations=2))
    out = []
    for i, sl in enumerate(ndimage.find_objects(labels)):
        region = labels[sl] == i + 1
        if region.sum() < min_area:
            continue
        rgb = np.array(col)[sl]
        a = np.array(opa)[sl] * region
        img = Image.fromarray(np.dstack([rgb, a]).astype(np.uint8), "RGBA")
        if stem == "left":
            img = img.rotate(90, expand=True)     # pointing right → pointing up
        out.append(img)
    print(f"  {set_id}: {len(out)} pieces")
    return out


def paste_rot(canvas, piece, base_xy, angle_deg, length, shade=1.0):
    """Pastes a leaf so its stem sits on base_xy, pointing at angle_deg (0 = up, + = clockwise)."""
    w, h = piece.size
    s = length / h
    p = piece.resize((max(1, int(w * s)), max(1, int(length))), Image.LANCZOS)
    if shade != 1.0:
        rgb = ImageEnhance.Brightness(p.convert("RGB")).enhance(shade)
        p = Image.merge("RGBA", (*rgb.split(), p.getchannel("A")))
    # Pad so the stem (bottom centre) is the rotation centre
    pw, ph = p.size
    pad = Image.new("RGBA", (pw, ph * 2), (0, 0, 0, 0))
    pad.paste(p, (0, 0))
    r = pad.rotate(-angle_deg, resample=Image.BICUBIC, expand=True)
    rw, rh = r.size
    canvas.alpha_composite(r, (int(base_xy[0] - rw / 2), int(base_xy[1] - rh / 2)))


def bezier(p0, p1, p2, t):
    return ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])


def twig(draw, p0, p1, p2, w0, w1, color):
    prev = p0
    for k in range(1, 25):
        t = k / 24
        pt = bezier(p0, p1, p2, t)
        draw.line([prev, pt], fill=color, width=max(1, int(w0 + (w1 - w0) * t)))
        prev = pt


def fill_transparent(img):
    """Gives transparent pixels the leaves' average colour so mipmaps do not fringe dark."""
    a = np.array(img)
    m = a[..., 3] > 128
    avg = a[m][:, :3].mean(axis=0) if m.any() else np.array([80, 100, 50])
    blur = np.array(img.convert("RGB").filter(ImageFilter.GaussianBlur(6)))
    alpha_blur = np.array(img.getchannel("A").filter(ImageFilter.GaussianBlur(6))).astype(float)[..., None] / 255.0
    near = np.where(alpha_blur > 0.02, blur / np.maximum(alpha_blur, 0.02), avg)
    near = np.clip(near, 0, 255)
    rgb = np.where(m[..., None], a[..., :3], near.astype(np.uint8))
    return Image.fromarray(np.dstack([rgb, a[..., 3]]).astype(np.uint8), "RGBA")


def cluster(name, leaves, rng, size=1024, count=34, length=(150, 230), spread=(30, 70), bark=(74, 58, 44), fruits=0):
    """A twig rising from the bottom centre with leaves along it and on two side shoots."""
    c = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    main = [(size * 0.5, size * 0.99), (size * rng.uniform(0.42, 0.58), size * 0.55), (size * rng.uniform(0.45, 0.55), size * 0.2)]
    shoots = [main]
    for j, t in enumerate((0.25, 0.38, 0.5, 0.62, 0.74)):
        side = -1 if j % 2 == 0 else 1
        b = bezier(*main, t + rng.uniform(-0.04, 0.04))
        reach = size * (0.42 - 0.2 * t) * rng.uniform(0.85, 1.1)
        shoots.append([b, (b[0] + side * reach * 0.5, b[1] - reach * 0.35), (b[0] + side * reach, b[1] - reach * 0.8)])
    for i, sh in enumerate(shoots):
        twig(d, *sh, 11 if i == 0 else 7, 3, bark)
    # Back-to-front: early leaves are drawn darker (they sit inside the cluster)
    placed = []
    for i in range(count):
        sh = shoots[0] if i % 3 == 0 else shoots[1 + (i % (len(shoots) - 1))]
        t = rng.uniform(0.18, 1.0)
        pt = bezier(*sh, t)
        pt2 = bezier(*sh, min(1.0, t + 0.02))
        tang = math.degrees(math.atan2(pt2[0] - pt[0], -(pt2[1] - pt[1])))
        ang = tang + rng.choice((-1, 1)) * rng.uniform(*spread)
        placed.append((pt, ang, rng.uniform(*length) * (0.8 + 0.3 * t)))
    for sh in shoots:  # a leaf at every tip
        pt = sh[2]
        placed.append((pt, math.degrees(math.atan2(sh[2][0] - sh[1][0], -(sh[2][1] - sh[1][1]))), length[1]))
    fruit_at = set(rng.sample(range(len(placed) // 3, len(placed)), fruits)) if fruits else set()
    for k, (pt, ang, ln) in enumerate(placed):
        shade = 0.62 + 0.45 * (k / len(placed)) + rng.uniform(-0.08, 0.08)
        paste_rot(c, rng.choice(leaves), pt, ang, ln, shade)
        if k in fruit_at:
            fruit(c, (pt[0], pt[1] + 30), rng.uniform(34, 46), rng)
    save(fill_transparent(c), name)


def fruit(c, xy, r, rng):
    """A shaded pomegranate: deep red sphere, warm highlight, a small crown on top."""
    x, y = xy
    ball = Image.new("RGBA", (int(r * 2 + 4), int(r * 2 + 8)), (0, 0, 0, 0))
    bd = ImageDraw.Draw(ball)
    base = (rng.randint(150, 185), rng.randint(28, 45), rng.randint(25, 38))
    for k in range(int(r), 0, -1):
        f = k / r
        col = tuple(int(base[j] * (0.55 + 0.45 * (1 - f) ** 0.6) + (60 if j == 0 else 25) * (1 - f) ** 3) for j in range(3))
        off = (1 - f) * r * 0.35
        bd.ellipse([r - k - off + 2, r - k - off + 6, r + k - off + 2, r + k - off + 6], fill=col + (255,))
    bd.polygon([(r - r * 0.18 + 2, 7), (r + 2, -1 + 4), (r + r * 0.18 + 2, 7)], fill=(120, 45, 30, 255))
    c.alpha_composite(ball, (int(x - r), int(y - r)))


def conifer(name, sprays, rng, w=1024, h=512):
    """A fir branch along +X (base at the left), sprays fanning off both sides."""
    c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    p0, p1, p2 = (0, h * 0.5), (w * 0.5, h * rng.uniform(0.45, 0.55)), (w * 0.97, h * 0.5)
    twig(d, p0, p1, p2, 12, 3, (70, 52, 38))
    items = []
    for i in range(30):
        t = 0.04 + 0.92 * i / 29
        pt = bezier(p0, p1, p2, t)
        side = 1 if i % 2 else -1
        items.append((pt, 90 + side * rng.uniform(25, 65), h * rng.uniform(0.5, 0.68) * (1.15 - 0.45 * t)))
    for t in (0.55, 0.7, 0.85):
        items.append((bezier(p0, p1, p2, t), 90 + rng.uniform(-10, 10), h * 0.6))
    for k, (pt, ang, ln) in enumerate(items):
        paste_rot(c, rng.choice(sprays), pt, ang, ln, 0.7 + 0.35 * k / len(items))
    save(fill_transparent(c), name)


def grass(name, blades, heads, rng, w=1024, h=512, count=38, head_share=0.12, tint=None):
    """A clump of blades rooted along the bottom middle, leaning outward."""
    c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for k in range(count):
        x = w * 0.5 + rng.gauss(0, w * 0.13)
        lean = (x - w * 0.5) / (w * 0.5) * 22 + rng.uniform(-10, 10)
        tall = rng.uniform(0.45, 0.98)
        src = rng.choice(heads) if heads and rng.random() < head_share else rng.choice(blades)
        shade = 0.7 + 0.4 * k / count + rng.uniform(-0.06, 0.06)
        paste_rot(c, src, (x, h * 0.995), lean, h * tall, shade)
    img = fill_transparent(c)
    if tint:
        rgb = Image.merge("RGB", img.split()[:3])
        rgb = Image.blend(rgb, Image.new("RGB", rgb.size, tint), 0.18)
        img = Image.merge("RGBA", (*rgb.split(), img.getchannel("A")))
    save(img, name)


def flowers(name, blades, rng, w=1024, h=512, count=16):
    """Meadow flowers among grass: red poppies, purple and white blooms on thin stems."""
    c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for k in range(14):   # grass underneath
        x = w * 0.5 + rng.gauss(0, w * 0.16)
        paste_rot(c, rng.choice(blades), (x, h * 0.995), (x - w * 0.5) / (w * 0.5) * 20 + rng.uniform(-8, 8), h * rng.uniform(0.35, 0.7), rng.uniform(0.6, 0.9))
    d = ImageDraw.Draw(c)
    palette = [((200, 30, 22), (120, 12, 10)), ((200, 30, 22), (120, 12, 10)), ((150, 80, 190), (80, 40, 120)),
               ((235, 235, 225), (170, 170, 150)), ((240, 190, 40), (170, 120, 20))]
    for k in range(count):
        x0 = w * 0.5 + rng.gauss(0, w * 0.17)
        top = (x0 + rng.uniform(-40, 40), h * rng.uniform(0.08, 0.5))
        mid = ((x0 + top[0]) / 2 + rng.uniform(-25, 25), (h + top[1]) / 2)
        twig(d, (x0, h), mid, top, 5, 3, (70, 105, 40))
        col, dark = rng.choice(palette)
        r = rng.uniform(22, 34)
        for pk in range(5):   # petals round the centre, darker toward the middle
            a = pk * 1.2566 + rng.uniform(-0.2, 0.2)
            px, py = top[0] + math.cos(a) * r * 0.55, top[1] + math.sin(a) * r * 0.35
            d.ellipse([px - r * 0.62, py - r * 0.45, px + r * 0.62, py + r * 0.45], fill=col + (255,))
        d.ellipse([top[0] - r * 0.3, top[1] - r * 0.22, top[0] + r * 0.3, top[1] + r * 0.22], fill=dark + (255,))
        d.ellipse([top[0] - r * 0.12, top[1] - r * 0.1, top[0] + r * 0.12, top[1] + r * 0.1], fill=(35, 30, 25, 255))
    save(fill_transparent(c), name)


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name + ".png")
    img.save(p)
    a = np.array(img.getchannel("A")) > 128
    print(f"  -> {name}.png  coverage {a.mean() * 100:.0f}%")


if __name__ == "__main__":
    rng = random.Random(7)
    print("Cutting leaves")
    beech = pieces("LeafSet024")
    hornbeam = pieces("LeafSet014")
    oak = pieces("LeafSet016")
    maple = pieces("LeafSet027")
    sprays = pieces("LeafSet019", stem="left", min_area=8000)
    blades = pieces("Foliage001", min_area=1500) + pieces("Foliage006", min_area=1500)
    heads = pieces("Foliage003", min_area=1500)
    print("Composing cards")
    cluster("oak_cluster", oak, rng, count=85, length=(95, 140))
    cluster("beech_cluster", beech + hornbeam, rng, count=95, length=(80, 125))
    cluster("maple_cluster", maple, rng, count=70, length=(100, 145), spread=(35, 80))
    cluster("pomegranate_cluster", hornbeam, rng, count=90, length=(70, 105), fruits=6)
    conifer("fir_branch", sprays, rng)
    grass("grass_clump", blades, heads, rng)
    grass("grass_dry", blades, heads, rng, count=30, head_share=0.3, tint=(170, 150, 90))
    grass("grass_wild", blades, heads, rng, count=22, head_share=0.55)
    flowers("flowers_meadow", blades, rng)
