"""Draw Lecdm's icon shape textures: Lecdm/Media/Mask-<shape>.tga (white inside, for
MaskTexture) and Ring-<shape>.tga (the shape's border, white, tinted in game), 64 px.

Run it with no arguments: .venv/bin/python art/make_masks.py (needs Pillow). Never edit the
TGAs by hand.
"""
import math
import pathlib

from PIL import Image, ImageChops, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
MEDIA = ROOT / "Lecdm" / "Media"
SIZE = 64
SCALE = 8  # drawn this much bigger, then shrunk: smooth edges
RING = 4   # the ring's width at 64 px


def polygon(points, inset):
    """A polygon on the big canvas, its points scaled to [0, 1] and pulled in by `inset` px."""
    big = SIZE * SCALE
    cx = cy = big / 2
    out = []
    for x, y in points:
        px, py = x * big, y * big
        dx, dy = px - cx, py - cy
        d = math.hypot(dx, dy) or 1
        out.append((px - dx / d * inset * SCALE, py - dy / d * inset * SCALE))
    return out


def shape(name, inset):
    big = SIZE * SCALE
    img = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(img)
    pad = inset * SCALE
    if name == "Round":
        draw.ellipse((pad, pad, big - 1 - pad, big - 1 - pad), fill=255)
    elif name == "Rounded":
        draw.rounded_rectangle((pad, pad, big - 1 - pad, big - 1 - pad), radius=big * 0.22 - pad / 2, fill=255)
    elif name == "Diamond":
        draw.polygon(polygon([(0.5, 0.0), (1.0, 0.5), (0.5, 1.0), (0.0, 0.5)], inset), fill=255)
    elif name == "Hexagon":
        pts = [(0.5 + 0.5 * math.cos(math.radians(a)), 0.5 + 0.5 * math.sin(math.radians(a)))
               for a in range(-90, 270, 60)]
        draw.polygon(polygon(pts, inset), fill=255)
    return img


def save(alpha, path):
    small = alpha.resize((SIZE, SIZE), Image.LANCZOS)
    rgba = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    rgba.putalpha(small)
    rgba.save(path)


def main():
    MEDIA.mkdir(exist_ok=True)
    for name in ("Round", "Rounded", "Diamond", "Hexagon"):
        outer = shape(name, 0)
        inner = shape(name, RING)
        save(outer, MEDIA / f"Mask-{name}.tga")
        save(ImageChops.subtract(outer, inner), MEDIA / f"Ring-{name}.tga")
        print(f"Wrote Lecdm/Media/Mask-{name}.tga and Ring-{name}.tga")


if __name__ == "__main__":
    main()
