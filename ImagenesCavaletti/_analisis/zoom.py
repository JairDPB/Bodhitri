# -*- coding: utf-8 -*-
"""Comparacion ampliada flotante vs en-celda para casos concretos."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

BASE = Path(r"C:\Users\jaduj\Documents\GitHub\Bodhitri\ImagenesCavaletti")
SAL = BASE / "salida" / "inspeccion"
SAL.mkdir(parents=True, exist_ok=True)
CEL = 300


def prep(p):
    im = Image.open(p)
    im.load()
    if im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info):
        im = im.convert("RGBA")
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
        im = Image.alpha_composite(bg, im)
    im = im.convert("RGB")
    g = im.convert("L").point(lambda v: 255 if v < 245 else 0)
    bb = g.getbbox()
    if bb:
        im = im.crop(bb)
    im = im.resize((max(1, int(im.width * min(CEL / im.width, CEL / im.height))),
                    max(1, int(im.height * min(CEL / im.width, CEL / im.height)))),
                   Image.LANCZOS)
    c = Image.new("RGB", (CEL, CEL), (255, 255, 255))
    c.paste(im, ((CEL - im.width) // 2, (CEL - im.height) // 2))
    return c


refs = sys.argv[1:]
W = CEL * 2 + 160
H = (CEL + 20) * len(refs) + 24
hoja = Image.new("RGB", (W, H), (240, 240, 240))
d = ImageDraw.Draw(hoja)
d.text((10, 6), "FLOTANTE (anclada)                 EN-CELDA (richData)", fill=(0, 0, 0))
y = 22
for ref in refs:
    d.text((8, y + 6), ref[:20], fill=(0, 0, 0))
    hoja.paste(prep(BASE / "flotantes" / f"{ref}.png"), (160, y))
    hoja.paste(prep(BASE / "encelda" / f"{ref}.png"), (160 + CEL, y))
    y += CEL + 20
out = SAL / ("zoom_" + "_".join(r[:8] for r in refs[:3]) + ".png")
hoja.save(out)
print(out, hoja.size)
