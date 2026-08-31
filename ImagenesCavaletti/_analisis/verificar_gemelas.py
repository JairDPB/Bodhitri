# -*- coding: utf-8 -*-
"""
Verificacion global del emparejamiento flotante <-> en-celda.
Extrae las 79+79 imagenes del xlsx y comprueba, sobre la matriz COMPLETA 79x79
(incluidas las 8 fotos de ambiente como competidoras), que la pareja asignada
es el maximo en ambas direcciones y con que margen.
"""
import io
import json
import math
import re
import xml.etree.ElementTree as ET
import zipfile
from operator import mul
from pathlib import Path

from PIL import Image

XLSX = Path(r"C:\Users\jaduj\Documents\PORTAFOLIO DYNAMICS - CAVALETTI .xlsx")
BASE = Path(r"C:\Users\jaduj\Documents\GitHub\Bodhitri\ImagenesCavaletti")
N = 48


def firma(data):
    im = Image.open(io.BytesIO(data))
    im.load()
    if im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info):
        im = im.convert("RGBA")
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
        im = Image.alpha_composite(bg, im)
    im = im.convert("RGB")
    g = im.convert("L").point(lambda v: 255 if v < 245 else 0)
    bb = g.getbbox() or (0, 0, im.width, im.height)
    rec = im.crop(bb)
    w, h = rec.size
    e = min(N / w, N / h)
    nw, nh = max(1, int(round(w * e))), max(1, int(round(h * e)))
    c = Image.new("RGB", (N, N), (255, 255, 255))
    c.paste(rec.resize((nw, nh), Image.LANCZOS), ((N - nw) // 2, (N - nh) // 2))
    px = list(c.getdata())
    v = [p[0] for p in px] + [p[1] for p in px] + [p[2] for p in px]
    m = sum(v) / len(v)
    v = [x - m for x in v]
    n = math.sqrt(sum(x * x for x in v))
    return [x / n for x in v] if n else [0.0] * len(v)


z = zipfile.ZipFile(XLSX)
rels = ET.fromstring(z.read("xl/richData/_rels/richValueRel.xml.rels"))
rich = sorted({t.get("Target").split("/")[-1] for t in rels},
              key=lambda s: int(re.search(r"(\d+)", s).group(1)))
draw = set()
for i in range(1, 9):
    r = ET.fromstring(z.read(f"xl/drawings/_rels/drawing{i}.xml.rels"))
    for t in r:
        draw.add(t.get("Target").split("/")[-1])
draw = sorted(draw, key=lambda s: int(re.search(r"(\d+)", s).group(1)))
print(f"flotantes={len(draw)}  encelda={len(rich)}")

FD = {n: firma(z.read("xl/media/" + n)) for n in draw}
FR = {n: firma(z.read("xl/media/" + n)) for n in rich}
z.close()

M = {a: {b: sum(map(mul, FD[a], FR[b])) for b in rich} for a in draw}

# asignacion del agente previo (solo las 71 de producto)
asig = {r["gemela_flotante"]: r["imagen_original"]
        for r in json.load(open(BASE / "mapa_encelda.json", encoding="utf-8"))}
ref_de = {r["gemela_flotante"]: r["referencia"]
          for r in json.load(open(BASE / "mapa_encelda.json", encoding="utf-8"))}

amb_bases = {"image11.png", "image21.png", "image31.png", "image41.png",
             "image51.png", "image61.png", "image71.png"}


def es_ambigua(fl):
    return fl in amb_bases or bool(re.fullmatch(r"image[1-7]\.png", fl))


filas = []
for fl, rc in sorted(asig.items(), key=lambda kv: int(re.search(r"(\d+)", kv[0]).group(1))):
    diag = M[fl][rc]
    # mejor rival por fila (otras rich) y por columna (otras flotantes)
    rf = max(((M[fl][b], b) for b in rich if b != rc))
    rcol = max(((M[a][rc], a) for a in draw if a != fl))
    filas.append({
        "ref": ref_de[fl], "flot": fl, "rich": rc, "corr": diag,
        "rival_fila": rf[1], "corr_fila": rf[0],
        "rival_col": rcol[1], "corr_col": rcol[0],
        "argmax_fila": diag >= rf[0], "argmax_col": diag >= rcol[0],
        "margen": min(diag - rf[0], diag - rcol[0]),
        "ambigua_nombre": es_ambigua(fl),
    })

mal = [f for f in filas if not (f["argmax_fila"] and f["argmax_col"])]
print(f"\nparejas que NO son maximo en ambas direcciones: {len(mal)} de {len(filas)}")
for f in mal:
    print(f"   {f['ref']:17s} {f['flot']:13s}->{f['rich']:13s} corr={f['corr']:.5f} "
          f"| fila:{f['rival_fila']} {f['corr_fila']:.5f} | col:{f['rival_col']} {f['corr_col']:.5f}")

amb = [f for f in filas if f["ambigua_nombre"]]
print(f"\n--- las {len(amb)} refs NO fijadas por la regla de nombre ---")
for f in sorted(amb, key=lambda x: x["margen"]):
    print(f"   {f['ref']:17s} {f['flot']:12s}->{f['rich']:12s} corr={f['corr']:.5f} "
          f"margen={f['margen']:+.5f} {'OK' if f['argmax_fila'] and f['argmax_col'] else 'REVISAR'}")

print("\n--- 8 margenes mas estrechos del total ---")
for f in sorted(filas, key=lambda x: x["margen"])[:8]:
    print(f"   {f['ref']:17s} corr={f['corr']:.5f} margen={f['margen']:+.5f} "
          f"rival_fila={f['rival_fila']} rival_col={f['rival_col']}")

json.dump(filas, open(BASE / "verificacion_gemelas.json", "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
print("\n->", BASE / "verificacion_gemelas.json")
