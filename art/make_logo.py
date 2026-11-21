"""Draws the Lecdm icon into art/ (512, 400, 256 and 128 px PNGs; 400 is the CurseForge and Wago
avatar), the in-game icon Lecdm/Media/Icon.tga (128 px; the game reads TGA with power-of-two
sizes; the .toc's IconTexture uses it for the AddOns list and the addon compartment), and the
listing banner art/lecdm-banner.png (1600x500: the icon, the name, the tagline and a sample bar).

The design: a cooldown, as the game draws one: a gold ring on a deep indigo rounded square, a
dark sweep over the part that has passed, a bright hand at its edge, and a small cyan "ready" pip.

Needs Pillow, and the Inter font for the banner (bold and semibold): point LECDM_FONT_BOLD and
LECDM_FONT_SEMI at the files (the default looks in .scratch/fonts), then run:
python3 art/make_logo.py
"""
import math
import os
import pathlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "art"
GAME_ICON = ROOT / "Lecdm" / "Media" / "Icon.tga"
S = 2048  # draw big, downsample for smooth edges

BG_TOP = (58, 54, 132)
BG_BOT = (14, 12, 40)
RIM = (150, 150, 230)
GOLD_TOP = (255, 228, 140)
GOLD_BOT = (220, 150, 40)
GLOW = (255, 210, 110)
CYAN = (90, 220, 255)
CYAN_DARK = (16, 70, 96)


def vgrad(w, h, top, bot):
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h))


def rounded_mask(box, radius, size=S):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def draw_icon():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    pad, radius = 40, 360
    body = rounded_mask([pad, pad, S - pad, S - pad], radius)

    # Background: indigo gradient, a soft light from the top, a thin bright rim.
    bg = vgrad(S, S, BG_TOP, BG_BOT).convert("RGBA")
    light = Image.new("L", (S, S), 0)
    ImageDraw.Draw(light).ellipse([-S * 0.2, -S * 0.75, S * 1.2, S * 0.55], fill=60)
    light = light.filter(ImageFilter.GaussianBlur(160))
    bg = Image.composite(Image.new("RGBA", (S, S), (255, 255, 255, 255)), bg, light)
    img.paste(bg, (0, 0), body)
    rim = ImageChops.subtract(body, rounded_mask([pad + 34, pad + 34, S - pad - 34, S - pad - 34], radius - 34))
    img.paste(Image.new("RGBA", (S, S), RIM + (255,)), (0, 0), rim.point(lambda v: v * 0.5))

    # The ring: a gold annulus, with its glow and shadow.
    cx, cy, r_out, r_in = S / 2, S / 2 + 20, 690, 500
    ring = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(ring)
    d.ellipse([cx - r_out, cy - r_out, cx + r_out, cy + r_out], fill=255)
    d.ellipse([cx - r_in, cy - r_in, cx + r_in, cy + r_in], fill=0)
    img.paste(Image.new("RGBA", (S, S), (0, 0, 0, 255)), (0, 50), ring.filter(ImageFilter.GaussianBlur(40)).point(lambda v: v * 0.6))
    glow = ring.filter(ImageFilter.GaussianBlur(120)).point(lambda v: v * 0.5)
    img.paste(Image.new("RGBA", (S, S), GLOW + (255,)), (0, 0), ImageChops.multiply(glow, body))
    img.paste(vgrad(S, S, GOLD_TOP, GOLD_BOT).convert("RGBA"), (0, 0), ring)

    # The sweep: a dark pie over the part of the cooldown that has passed (from 12 o'clock,
    # clockwise to about 4 o'clock), across the ring and its middle.
    start, end = -90, 30  # degrees, PIL's 0 is 3 o'clock, angles grow clockwise
    sweep = Image.new("L", (S, S), 0)
    ImageDraw.Draw(sweep).pieslice([cx - r_out - 8, cy - r_out - 8, cx + r_out + 8, cy + r_out + 8], start, end, fill=255)
    img.paste(Image.new("RGBA", (S, S), (6, 6, 24, 255)), (0, 0), sweep.point(lambda v: v * 0.72))
    # The middle: a darker disc, so the ring reads as a ring.
    mid = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mid).ellipse([cx - r_in + 30, cy - r_in + 30, cx + r_in - 30, cy + r_in - 30], fill=255)
    img.paste(Image.new("RGBA", (S, S), (10, 8, 30, 255)), (0, 0), mid.point(lambda v: v * 0.45))

    # The hand: a bright line from the middle to the sweep's edge, with a soft glow.
    a = math.radians(end)
    hx, hy = cx + math.cos(a) * (r_out + 10), cy + math.sin(a) * (r_out + 10)
    hand = Image.new("L", (S, S), 0)
    ImageDraw.Draw(hand).line([(cx, cy), (hx, hy)], fill=255, width=70)
    img.paste(Image.new("RGBA", (S, S), (255, 245, 210, 255)), (0, 0), hand.filter(ImageFilter.GaussianBlur(30)).point(lambda v: v * 0.6))
    img.paste(Image.new("RGBA", (S, S), (255, 250, 230, 255)), (0, 0), hand)
    dot = Image.new("L", (S, S), 0)
    ImageDraw.Draw(dot).ellipse([cx - 90, cy - 90, cx + 90, cy + 90], fill=255)
    img.paste(Image.new("RGBA", (S, S), (255, 250, 230, 255)), (0, 0), dot)

    # The cyan "ready" pip, top right.
    px, py, pr = S - pad - 330, pad + 330, 140
    d = ImageDraw.Draw(img)
    d.ellipse([px - pr - 22, py - pr - 22, px + pr + 22, py + pr + 22], fill=CYAN_DARK + (255,))
    d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=CYAN + (255,))
    shine = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shine).ellipse([px - pr * 0.6, py - pr * 0.75, px + pr * 0.2, py - pr * 0.1], fill=110)
    img.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255)), (0, 0), shine.filter(ImageFilter.GaussianBlur(18)))

    # Keep everything inside the rounded square.
    img.putalpha(ImageChops.multiply(img.getchannel("A"), body))
    return img


FONTS = ROOT / ".scratch" / "fonts"
BOLD = os.environ.get("LECDM_FONT_BOLD", str(FONTS / "Inter-Bold.ttf"))
SEMI = os.environ.get("LECDM_FONT_SEMI", str(FONTS / "Inter-SemiBold.ttf"))
TAGLINE = "Your cooldowns and buffs, your way."


def tile(icon, size, look):
    """A sample icon for the banner: ready (gold glow), cooling down (grey with a sweep), or a
    missing buff (dimmed red with a red glow)."""
    pad = size // 4
    out = Image.new("RGBA", (size + 2 * pad, size + 2 * pad), (0, 0, 0, 0))
    ic = icon.resize((size, size), Image.LANCZOS)
    if look in ("cooldown", "missing"):
        grey = ic.convert("L").convert("RGBA")
        r, g, b, _ = grey.split()
        if look == "missing":
            ic = Image.merge("RGBA", (r, g.point(lambda v: v * 0.4), b.point(lambda v: v * 0.4), ic.getchannel("A")))
        else:
            ic = Image.merge("RGBA", (r, g, b, ic.getchannel("A")))
            swipe = Image.new("L", (size, size), 0)
            ImageDraw.Draw(swipe).pieslice([-size, -size, 2 * size, 2 * size], -90, 140, fill=150)
            ic.paste(Image.new("RGBA", (size, size), (0, 0, 0, 255)), (0, 0), ImageChops.multiply(swipe, ic.getchannel("A")))
    if look in ("ready", "missing"):
        color = (255, 210, 90, 255) if look == "ready" else (255, 50, 40, 255)
        ring = Image.new("L", out.size, 0)
        ImageDraw.Draw(ring).rounded_rectangle([pad - 6, pad - 6, pad + size + 6, pad + size + 6], radius=size // 5, outline=255, width=8)
        ring = ring.filter(ImageFilter.GaussianBlur(6))
        for _ in range(2):  # twice, for a strong glow
            out.paste(Image.new("RGBA", out.size, color), (0, 0), ring)
    out.alpha_composite(ic, (pad, pad))
    return out


def banner(icon):
    from PIL import ImageFont
    W, H = 1600, 500
    img = vgrad(W, H, BG_TOP, BG_BOT).convert("RGBA")
    light = Image.new("L", (W, H), 0)
    ImageDraw.Draw(light).ellipse([-200, -500, 1100, 300], fill=55)
    img = Image.composite(Image.new("RGBA", (W, H), (255, 255, 255, 255)), img, light.filter(ImageFilter.GaussianBlur(120)))
    img.alpha_composite(icon.resize((380, 380), Image.LANCZOS), (60, 60))
    d = ImageDraw.Draw(img)
    title = ImageFont.truetype(BOLD, 140)
    tag = ImageFont.truetype(SEMI, 46)
    d.text((500, 52), "Lecdm", font=title, fill=GOLD_TOP)
    d.line([(506, 228), (1530, 228)], fill=GOLD_BOT + (255,), width=3)
    d.text((506, 244), TAGLINE, font=tag, fill=(220, 222, 245))
    # A sample icon bar: ready (glowing), ready, cooling down, a buff that's missing.
    x = 506
    for look in ("ready", "plain", "cooldown", "missing", "plain"):
        img.alpha_composite(tile(icon, 104, look), (x - 26, 318))
        x += 104 + 22
    img.convert("RGB").save(ART / "lecdm-banner.png")
    # Checks without looking at it: the text fits, the tiles sit inside the canvas.
    tb = d.textbbox((500, 52), "Lecdm", font=title)
    tg = d.textbbox((506, 244), TAGLINE, font=tag)
    print("title", tb, "tagline", tg, "fits:", tg[2] < W - 40 and tb[3] < 228, "tiles end at x", x, "y", 318 + 156)


def main():
    big = draw_icon()
    for px in (512, 400, 256, 128):
        big.resize((px, px), Image.LANCZOS).save(ART / f"lecdm-icon-{px}.png")
    GAME_ICON.parent.mkdir(exist_ok=True)
    big.resize((128, 128), Image.LANCZOS).save(GAME_ICON)
    print(f"Wrote art/lecdm-icon-{{512,400,256,128}}.png and {GAME_ICON.relative_to(ROOT)}")
    if os.path.exists(BOLD) and os.path.exists(SEMI):
        banner(big)
        print("Wrote art/lecdm-banner.png")
    else:
        print("No Inter font files (LECDM_FONT_BOLD, LECDM_FONT_SEMI): skipped the banner")


if __name__ == "__main__":
    main()
