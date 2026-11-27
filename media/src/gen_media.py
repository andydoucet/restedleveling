#!/usr/bin/env python3
"""Builds every texture in media/ from the sources in media/src/ (run from the repository root):

    python3 media/src/gen_media.py

Sources (all generated for this project, no third-party art):
  logo_concept_v0.png  desk concept (grok-imagine): bedroll under a crescent moon
  stage_inn_src.png    grok-imagine-image-quality: tavern interior at night (detail-card stage, resting)
  stage_wild_src.png   grok-imagine-image-quality: forest road at night (detail-card stage, not resting)
  wood_src.png         grok-imagine-image-quality: seamless dark oak planks (Default-style title rail and body)
Procedural textures (bar, ring, glow, pip, hatch, disc) are drawn here. Output is 32-bit TGA, power-of-two sizes.
"""
import math
import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

SRC = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(SRC)


def save(img, name):
    assert img.size[0] & (img.size[0] - 1) == 0 and img.size[1] & (img.size[1] - 1) == 0, name
    img.convert("RGBA").save(os.path.join(OUT, name), compression=None)


def round_mask(size, feather=1.5):
    s = size * 4
    m = Image.new("L", (s, s), 0)
    ImageDraw.Draw(m).ellipse((2, 2, s - 3, s - 3), fill=255)
    return m.resize((size, size), Image.LANCZOS).filter(ImageFilter.GaussianBlur(feather / 4))


def vignette(img, strength=0.65):
    w, h = img.size
    v = Image.new("L", (w, h), 0)
    px = v.load()
    for y in range(h):
        for x in range(w):
            dx, dy = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
            px[x, y] = int(255 * max(0.0, 1 - strength * min(1.0, (dx * dx + dy * dy) ** 0.9)))
    black = Image.new("RGB", (w, h), (0, 0, 0))
    return Image.composite(img.convert("RGB"), black, v)


def icon(size, name):
    src = Image.open(os.path.join(SRC, "logo_concept_v0.png")).convert("RGB")
    crop = src.crop((170, 30, 730, 590)).resize((size, size), Image.LANCZOS)   # the moon and the zZz only
    crop = ImageEnhance.Contrast(crop).enhance(1.25)
    crop = ImageEnhance.Brightness(crop).enhance(1.1)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(crop, (0, 0), round_mask(size))
    ring = Image.new("RGBA", (size * 4, size * 4), (0, 0, 0, 0))
    w = max(2, size // 22) * 4
    ImageDraw.Draw(ring).ellipse((w // 2, w // 2, size * 4 - w // 2, size * 4 - w // 2), outline=(214, 172, 84, 255), width=w)
    out.alpha_composite(ring.resize((size, size), Image.LANCZOS))
    save(out, name)


def hero_bg():
    src = Image.open(os.path.join(SRC, "logo_concept_v0.png")).convert("RGB")
    img = src.crop((0, 260, 1024, 772)).resize((512, 256), Image.LANCZOS)
    img = ImageEnhance.Brightness(img).enhance(0.55)
    # Darker on the left, where the portrait and text sit.
    grad = Image.new("L", (512, 256))
    gp = grad.load()
    for x in range(512):
        a = int(255 * min(1.0, 0.25 + 0.75 * (x / 511) ** 1.4))
        for y in range(256):
            gp[x, y] = a
    out = Image.composite(img, Image.new("RGB", img.size, (8, 6, 12)), grad)
    save(vignette(out, 0.5), "hero_bg.tga")


def stage(src_name, out_name):
    img = Image.open(os.path.join(SRC, src_name)).convert("RGB").resize((512, 512), Image.LANCZOS)
    img = ImageEnhance.Brightness(img).enhance(0.8)
    save(vignette(img, 0.75), out_name)


def bar():
    w, h = 256, 32
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        v = 1.0 - 0.38 * t + (0.22 if t < 0.42 else 0) * (1 - t / 0.42)   # gloss on the top half
        c = int(255 * max(0.0, min(1.0, v)))
        for x in range(w):
            px[x, y] = (c, c, c, 255)
    save(img, "bar.tga")


def ring(size=128):
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((6, 6, s - 7, s - 7), outline=(255, 255, 255, 255), width=int(s * 0.045))
    img = img.resize((size, size), Image.LANCZOS)
    save(img, "ring.tga")


def glow(size=128):
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - size / 2 + 0.5, y - size / 2 + 0.5) / (size / 2)
            a = max(0.0, 1 - r) ** 2
            px[x, y] = (255, 255, 255, int(255 * a))
    save(img, "glow.tga")


def pip(size=32):
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((4, 4, s - 5, s - 5), fill=(255, 255, 255, 255))
    hl = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse((s * 0.22, s * 0.12, s * 0.62, s * 0.42), fill=(255, 255, 255, 140))
    img = img.resize((size, size), Image.LANCZOS)
    shade = Image.new("RGBA", (size, size))
    sp = shade.load()
    ip = img.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = ip[x, y]
            k = 1 - 0.35 * (y / (size - 1))
            sp[x, y] = (int(r * k), int(g * k), int(b * k), a)
    shade.alpha_composite(hl.resize((size, size), Image.LANCZOS))
    save(shade, "pip.tga")


def disc(size=64):
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    img.putalpha(round_mask(size, 2))
    save(img, "disc.tga")


def shade(w=8, h=64):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        a = int(255 * (y / (h - 1)) ** 1.6)   # transparent at the top, opaque at the bottom
        for x in range(w):
            px[x, y] = (0, 0, 0, a)
    save(img, "shade.tga")


def wood():
    img = Image.open(os.path.join(SRC, "wood_src.png")).convert("RGB").resize((512, 512), Image.LANCZOS)
    img = ImageEnhance.Brightness(img).enhance(1.35)
    save(img.crop((0, 0, 512, 256)), "wood.tga")


def moon(size=32):
    s = size * 4
    img = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(img)
    d.ellipse((4, 4, s - 5, s - 5), fill=255)
    d.ellipse((int(s * 0.32), -int(s * 0.06), s + int(s * 0.18), int(s * 0.78)), fill=0)   # bite out: a crescent
    a = img.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(a)
    save(out, "moon.tga")


def tail(size=32):
    s = size * 4
    img = Image.new("L", (s, s), 0)
    ImageDraw.Draw(img).polygon([(0, 0), (s - 1, 0), (s // 2, s - 1)], fill=255)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(img.resize((size, size), Image.LANCZOS))
    save(out, "tail.tga")
    left = Image.new("L", (s, s), 0)   # the same tail pointing left, for a bubble beside its speaker
    ImageDraw.Draw(left).polygon([(s - 1, 0), (s - 1, s - 1), (0, s // 2)], fill=255)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(left.resize((size, size), Image.LANCZOS))
    save(out, "tail_l.tga")
    save(out.transpose(Image.FLIP_LEFT_RIGHT), "tail_r.tga")


def fade_h(w=256, h=8):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for x in range(w):
        a = int(255 * (1 - x / (w - 1)) ** 1.3)   # opaque on the left, clear on the right
        for y in range(h):
            px[x, y] = (0, 0, 0, a)
    save(img, "fade_h.tga")


# Colours are baked into small textures and drawn with a white vertex colour, so a fill looks the same whatever a
# renderer does with vertex colours (wow-ui-sim treats them as linear and brightens dark ones; the game does not).
PAL = {
    "body": (18, 15, 12), "panel": (56, 43, 30), "inset": (40, 31, 23), "strip": (48, 37, 26), "warn": (34, 14, 12),
    "well": (11, 9, 8), "bronze": (112, 88, 56), "bronze_hi": (176, 138, 76), "line": (58, 49, 38), "parch": (240, 227, 196),
    "ink": (52, 34, 18), "gold": (206, 160, 74), "black": (0, 0, 0), "row0": (50, 38, 28), "row1": (58, 46, 34),
    "toast": (24, 20, 16), "iron": (23, 25, 27), "lip": (128, 96, 57), "btn": (30, 23, 15), "btn_hi": (46, 36, 22),
    "enamel": (110, 28, 28), "enamel_hi": (150, 44, 38), "rule": (107, 82, 38), "top": (58, 46, 28), "ghost": (40, 35, 28),
    "div": (60, 46, 30), "bronze_btn": (89, 69, 39), "bevel_hi": (150, 116, 66), "bevel_lo": (36, 28, 18), "band": (30, 24, 19), "bubble": (28, 25, 20), "bubble_edge": (107, 83, 68), "edge": (74, 54, 32), "host_well": (21, 16, 11), "host_stage": (26, 18, 12), "host_line": (42, 33, 24),
}
STATES = {"full": (61, 220, 106), "near": (242, 219, 59), "resting": (232, 144, 46), "outside": (210, 58, 42),
          "max": (120, 115, 107), "done": (120, 115, 107), "cur": (118, 185, 220)}


def solid(name, rgb, size=8):
    save(Image.new("RGBA", (size, size), rgb + (255,)), name)


def mix(a, b, k):
    return tuple(int(round(x + (y - x) * k)) for x, y in zip(a, b))


def swatches():
    for name, rgb in PAL.items():
        solid("sw_" + name + ".tga", rgb)
    for st, rgb in STATES.items():
        solid("st_" + st + ".tga", rgb)
        solid("chip_" + st + ".tga", mix(PAL["inset"], rgb, 0.16))
        for alt in (0, 1):
            k = {"max": 0, "done": 0, "near": 0.035, "outside": 0.09}.get(st, 0.06)
            solid("row_%s_%d.tga" % (st, alt), mix(PAL["row%d" % alt], rgb, k))
        # the bubble bar's fill: the gloss gradient in this state's colour
        bar = Image.open(os.path.join(OUT, "bar.tga")).convert("RGBA")
        px = bar.load()
        out = Image.new("RGBA", bar.size)
        op = out.load()
        for y in range(bar.size[1]):
            for x in range(bar.size[0]):
                v = px[x, y][0] / 255
                op[x, y] = (min(255, int(rgb[0] * v * 1.08)), min(255, int(rgb[1] * v * 1.08)), min(255, int(rgb[2] * v * 1.08)), 255)
        save(out, "bar_%s.tga" % st)
    pip = Image.open(os.path.join(OUT, "pip.tga")).convert("RGBA")
    for st, rgb in STATES.items():   # compact-mode bubbles: the pip's shading in the state colour
        pp, out = pip.load(), Image.new("RGBA", pip.size)
        op = out.load()
        for y in range(pip.size[1]):
            for x in range(pip.size[0]):
                r, g, b, a = pp[x, y]
                v = r / 255
                op[x, y] = (min(255, int(rgb[0] * v * 1.1)), min(255, int(rgb[1] * v * 1.1)), min(255, int(rgb[2] * v * 1.1)), a)
        save(out, "pip_%s.tga" % st)
    for name, rgb in (("disc_gold", PAL["gold"]), ("disc_dark", PAL["well"]), ("moon_gold", (242, 210, 122)), ("moon_dim", (58, 52, 40))):
        src = Image.open(os.path.join(OUT, ("disc" if name.startswith("disc") else "moon") + ".tga")).convert("RGBA")
        col = Image.new("RGBA", src.size, rgb + (255,))
        col.putalpha(src.split()[3])
        save(col, name + ".tga")
    wood = Image.open(os.path.join(OUT, "wood.tga")).convert("RGB")
    save(ImageEnhance.Brightness(wood).enhance(0.42), "wood_dark.tga")
    shade_src = Image.open(os.path.join(OUT, "shade.tga")).convert("RGBA")
    for name, rgb in (("shade_cold", (26, 40, 78)), ("shade_fog", (86, 98, 120))):
        col = Image.new("RGBA", shade_src.size, rgb + (255,))
        col.putalpha(shade_src.split()[3])
        save(col, name + ".tga")


def pack_edge(F, e, name):
    S = F.size[0]
    mid = S // 2 - e // 2
    tiles = [
        F.crop((0, mid, e, mid + e)),                                   # left: x outer -> inner
        F.crop((S - e, mid, S, mid + e)),                               # right: x inner -> outer
        F.crop((mid, 0, mid + e, e)).transpose(Image.TRANSPOSE),        # top: outer row -> x = 0
        F.crop((mid, S - e, mid + e, S)).transpose(Image.TRANSPOSE),    # bottom: inner row -> x = 0
        F.crop((0, 0, e, e)), F.crop((S - e, 0, S, e)),
        F.crop((0, S - e, e, S)), F.crop((S - e, S - e, S, S)),
    ]
    out = Image.new("RGBA", (8 * e, e), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        out.paste(t, (i * e, 0))
    save(out, name)


def rivet_img(d, cx, cy, r):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(26, 16, 8, 255))
    d.ellipse((cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1), fill=(176, 138, 74, 255))
    d.ellipse((cx - r * 0.55, cy - r * 0.6, cx, cy - r * 0.05), fill=(240, 215, 140, 255))


def frame_main(S=128, e=32, oak=14):   # drawn at 2x, shown at edgeSize 16: a ~10 px band
    """A slim furnished frame, not armour: 1 px black, a dark oak band with quiet grain, one bronze lip, 1 px black,
    and a small bronze stud in each corner. No straps, no mid-edge rivets."""
    wood = Image.open(os.path.join(SRC, "wood_src.png")).convert("RGB").resize((S * 2, S * 2), Image.LANCZOS)
    wood = ImageEnhance.Brightness(wood).enhance(1.25)
    wood = ImageEnhance.Contrast(wood).enhance(1.05).resize((S, S), Image.LANCZOS)
    vert = wood.transpose(Image.ROTATE_90)
    F = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    band = Image.new("L", (S, S), 0)
    bd = ImageDraw.Draw(band)
    bd.rectangle((0, 0, S - 1, S - 1), fill=255)
    bd.rectangle((oak + 6, oak + 6, S - oak - 7, S - oak - 7), fill=0)
    tb = Image.new("L", (S, S), 0)
    ImageDraw.Draw(tb).polygon([(0, 0), (S, 0), (S - oak, oak), (oak, oak)], fill=255)
    ImageDraw.Draw(tb).polygon([(0, S), (S, S), (S - oak, S - oak), (oak, S - oak)], fill=255)
    F.paste(Image.composite(wood, vert, tb).convert("RGBA"), (0, 0), band)
    d = ImageDraw.Draw(F)
    d.rectangle((0, 0, S - 1, S - 1), outline=(8, 6, 4, 255), width=2)                      # 1 px black outside
    d.rectangle((2, 2, S - 3, S - 3), outline=(92, 70, 44, 255), width=1)                    # a lit outer arris
    i0 = oak + 2
    d.rectangle((i0, i0, S - i0 - 1, S - i0 - 1), outline=(132, 102, 58, 255), width=2)      # one bronze lip
    d.rectangle((i0 + 2, i0 + 2, S - i0 - 3, S - i0 - 3), outline=(8, 6, 4, 255), width=2)   # 1 px black inside
    for cx, cy in ((9, 9), (S - 10, 9), (9, S - 10), (S - 10, S - 10)):
        rivet_img(d, cx, cy, 5)
    pack_edge(F, e, "frame_edge.tga")


def frame_surface(S=64, e=16):
    """Floating panels (tooltips, toasts, the banner, menus): a quiet 1 px #6B5344 outline over a 1 px black shadow,
    with a 3 px stud in each corner. The hardware stays small; the oak fill carries the material."""
    F = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(F)
    d.rectangle((0, 0, S - 1, S - 1), outline=(8, 6, 4, 255))
    d.rectangle((1, 1, S - 2, S - 2), outline=(107, 83, 68, 255))
    for cx, cy in ((2, 2), (S - 3, 2), (2, S - 3), (S - 3, S - 3)):
        d.ellipse((cx - 1.5, cy - 1.5, cx + 1.5, cy + 1.5), fill=(176, 138, 74, 255))
    pack_edge(F, e, "edge_surface.tga")


def bubble_tails(size=16):
    """Speech-bubble tails with the colours baked in (the simulator brightens tinted textures): dark fill, bronze
    edge on the two outer sides. Down, left and right."""
    s = size * 4
    fill, edge = PAL["bubble"] + (255,), PAL["bubble_edge"] + (255,)
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(0, 0), (s - 1, 0), (s // 2, s - 1)], fill=edge)
    d.polygon([(6, 0), (s - 7, 0), (s // 2, s - 9)], fill=fill)
    down = img.resize((size, size), Image.LANCZOS)
    save(down, "btail_d.tga")
    save(down.rotate(-90, expand=True), "btail_l.tga")
    save(down.rotate(90, expand=True), "btail_r.tga")


def rail(w=512, h=32):
    """The title rail: one quiet dark-oak board, grain along its length, a lit top arris and a dark lower edge."""
    wood = Image.open(os.path.join(SRC, "wood_src.png")).convert("RGB").resize((w, w), Image.LANCZOS).crop((0, 40, w, 40 + h))
    img = ImageEnhance.Contrast(ImageEnhance.Brightness(wood).enhance(1.0)).enhance(0.75)   # flatter grain
    img = Image.blend(img, Image.new("RGB", img.size, (33, 27, 20)), 0.35)                  # on a #211B14 base
    d = ImageDraw.Draw(img)
    d.line((0, 0, w, 0), fill=(84, 62, 38), width=1)
    d.line((0, h - 1, w, h - 1), fill=(14, 10, 6), width=1)
    save(img, "rail.tga")


def enamel(name, rgb):
    w, h = 128, 32
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        k = 1.25 - 0.55 * t
        col = tuple(min(255, int(c * k)) for c in rgb)
        if y <= 1: col = mix(col, (240, 215, 150), 0.6)
        if y >= h - 2: col = (40, 22, 10)
        for x in range(w):
            px[x, y] = col + (255,)
    save(img, name + ".tga")
    hi = ImageEnhance.Brightness(img).enhance(1.25)
    save(hi, name + "_hi.tga")


def rings(size=128):
    s = size * 4
    def ring(width, rgb_outer, rgb_inner, name):
        img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for k in range(width):
            col = mix(rgb_outer, rgb_inner, k / max(1, width - 1))
            d.ellipse((6 + k, 6 + k, s - 7 - k, s - 7 - k), outline=col + (255,), width=1)
        save(img.resize((size, size), Image.LANCZOS), name)
    ring(int(s * 0.05), (240, 210, 140), (110, 80, 36), "ring_bronze.tga")
    for st, rgb in STATES.items():
        ring(int(s * 0.016), rgb, rgb, "ring_%s.tga" % st)


CHIP = {"full": ((27, 92, 52), (229, 255, 232)), "near": ((58, 66, 16), (228, 240, 106)),
        "resting": ((90, 52, 18), (240, 196, 138)), "outside": ((110, 34, 34), (255, 212, 212)), "cur": ((30, 58, 86), (190, 225, 245)),
        "max": ((34, 32, 30), (190, 184, 170)), "done": ((34, 32, 30), (190, 184, 170))}


def chips():
    for st, (fill, _) in CHIP.items():
        solid("chipfill_" + st + ".tga", fill)


def hatch(size=32):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            if (x + y) % 8 < 3:
                px[x, y] = (255, 255, 255, 255)
    save(img, "hatch.tga")


if __name__ == "__main__":
    icon(64, "icon.tga")
    icon(128, "logo.tga")
    hero_bg()
    stage("stage_inn_src.png", "stage_inn.tga")
    stage("stage_wild_src.png", "stage_wild.tga")
    bar()
    ring()
    glow()
    pip()
    disc()
    hatch()
    shade()
    wood()
    moon()
    tail()
    fade_h()
    swatches()
    frame_main()
    frame_surface()
    bubble_tails()
    rail()
    enamel("btn_red", (142, 30, 30))
    enamel("btn_blue", (30, 58, 142))
    enamel("btn_gold", (150, 104, 30))   # the main action: red is kept for "not resting" only
    rings()
    chips()
    print("media written to", OUT)
