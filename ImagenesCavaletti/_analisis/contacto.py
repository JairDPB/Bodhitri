# -*- coding: utf-8 -*-
"""Hoja de contacto: flotante | encelda | encelda del rival, para inspeccion visual."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

BASE = Path(r"C:\Users\jaduj\Documents\GitHub\Bodhitri\ImagenesCavaletti")
SAL = BASE / "salida" / "inspeccion"
SAL.mkdir(parents=True, exist_ok=True)

CEL = 210
res = json.load(open(BASE / "salida" / "resumen_cruce.json", encoding="utf-8"))
disc = res["discrepancias"]


def thumb(p):
    im = Image.open(p)
    im.load()
    if im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info):
        im = im.convert("RGBA")
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
        im = Image.alpha_composite(bg, im)
    im = im.convert("RGB")
    im.thumbnail((CEL - 8, CEL - 8), Image.LANCZOS)
    c = Image.new("RGB", (CEL, CEL), (255, 255, 255))
    c.paste(im, ((CEL - im.width) // 2, (CEL - im.height) // 2))
    return c


grupo = sys.argv[1] if len(sys.argv) > 1 else "disc"
filas = disc
nombre = "discrepancias"

W = CEL * 3 + 150
H = (CEL + 22) * len(filas) + 30
hoja = Image.new("RGB", (W, H), (245, 245, 245))
d = ImageDraw.Draw(hoja)
d.text((10, 8), "FLOTANTE (anclada)      EN-CELDA (misma ref)      EN-CELDA (rival)",
       fill=(0, 0, 0))

y = 30
for f in filas:
    ref = f["ref"]
    d.text((10, y + 4), ref, fill=(0, 0, 0))
    d.text((10, y + 18), f"d={f['corr_ar']:.3f}", fill=(80, 80, 80))
    d.text((10, y + 32), f"r={f['corr_rival']:.3f}", fill=(150, 0, 0))
    d.text((10, y + 46), f["mejor_rival"][:14], fill=(150, 0, 0))
    x = 150
    for p in (BASE / "flotantes" / f"{ref}.png",
              BASE / "encelda" / f"{ref}.png",
              BASE / "encelda" / f"{f['mejor_rival']}.png"):
        if p.exists():
            hoja.paste(thumb(p), (x, y))
        x += CEL
    y += CEL + 22

out = SAL / f"contacto_{nombre}.png"
hoja.save(out)
print(out, hoja.size)
