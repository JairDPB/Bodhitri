# -*- coding: utf-8 -*-
"""
Extrae las imagenes FLOTANTES (xl/drawings/) del portafolio Cavaletti y las
renombra con su codigo DYNAMICS, listo para subir a Business Central.

El .xlsx original SOLO se abre en lectura (zipfile 'r' + openpyxl read_only).
Nunca se escribe fuera de C:\\Users\\jaduj\\Documents\\GitHub\\Bodhitri\\ImagenesCavaletti

Cadena de relaciones que se resuelve:
    xl/workbook.xml               nombre de hoja  -> r:id
    xl/_rels/workbook.xml.rels    r:id            -> xl/worksheets/sheetN.xml
    xl/worksheets/_rels/*.rels    hoja            -> xl/drawings/drawingN.xml
    xl/drawings/drawingN.xml      anclaje         -> fila (base 0) + r:embed
    xl/drawings/_rels/*.rels      r:embed         -> xl/media/imageN.png
"""
import json
import os
import posixpath
import re
import shutil
import struct
import sys
import zipfile
import xml.etree.ElementTree as ET
from collections import defaultdict

import openpyxl

# ---------------------------------------------------------------- configuracion
SRC = r"C:\Users\jaduj\Documents\PORTAFOLIO DYNAMICS - CAVALETTI .xlsx"
OUT_DIR = r"C:\Users\jaduj\Documents\GitHub\Bodhitri\ImagenesCavaletti"
IMG_DIR = os.path.join(OUT_DIR, "flotantes")
DUP_DIR = os.path.join(OUT_DIR, "flotantes_duplicados")
MAP_JSON = os.path.join(OUT_DIR, "mapa_flotantes.json")
DIAG_JSON = os.path.join(OUT_DIR, "diagnostico_flotantes.json")

HOJAS_IGNORADAS = {"HOJA1"}
# el encabezado del id cambia de ortografia entre hojas
ALIAS_DYNAMICS = {"DYNAMICS", "DINAMYCS", "DINAMICS", "DYNAMYCS"}

NS = {
    "r":   "http://schemas.openxmlformats.org/package/2006/relationships",
    "or":  "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "xdr": "http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing",
    "a":   "http://schemas.openxmlformats.org/drawingml/2006/main",
    "m":   "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
}
R_ID = "{%s}id" % NS["or"]
R_EMBED = "{%s}embed" % NS["or"]


# ---------------------------------------------------------------- utilidades
def norm(v):
    """Normaliza un encabezado para compararlo: sin acentos raros, sin espacios."""
    if v is None:
        return ""
    s = str(v).replace("\xa0", " ").strip().upper()
    return re.sub(r"\s+", " ", s)


def png_size(data):
    """Ancho/alto reales leyendo la cabecera IHDR del PNG (sin depender de Pillow)."""
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        return None, None
    if data[12:16] != b"IHDR":
        return None, None
    w, h = struct.unpack(">II", data[16:24])
    return int(w), int(h)


def load_rels(z, part):
    """Lee el _rels de una parte y devuelve {rId: ruta absoluta dentro del zip}."""
    base = posixpath.dirname(part)
    rels_path = posixpath.join(base, "_rels", posixpath.basename(part) + ".rels")
    out = {}
    if rels_path not in z.namelist():
        return out
    root = ET.fromstring(z.read(rels_path))
    for rel in root.findall("r:Relationship", NS):
        rid = rel.get("Id")
        target = rel.get("Target")
        mode = rel.get("TargetMode")
        if not rid or not target or mode == "External":
            continue
        out[rid] = posixpath.normpath(posixpath.join(base, target)).lstrip("/")
    return out


# ---------------------------------------------------------------- lectura hojas
def leer_tablas():
    """
    Para cada hoja de producto devuelve:
      {'fila_encabezado', 'col_dynamics', 'col_imagen', 'refs': {fila: referencia}}
    El encabezado se localiza buscando la fila que contiene COSTO y PRECIO DE VENTA.
    """
    wb = openpyxl.load_workbook(SRC, read_only=True, data_only=True)
    tablas = {}
    try:
        for ws in wb.worksheets:
            if norm(ws.title) in HOJAS_IGNORADAS:
                continue
            filas = list(ws.iter_rows(values_only=True))
            hdr_idx = None
            for i, row in enumerate(filas):
                vals = {norm(v) for v in row if v is not None}
                if "COSTO" in vals and "PRECIO DE VENTA" in vals:
                    hdr_idx = i
                    break
            if hdr_idx is None:
                print("  !! %s: no se hallo fila de encabezado" % ws.title)
                continue

            hdr = filas[hdr_idx]
            col_dyn = col_img = None
            for c, v in enumerate(hdr, 1):
                n = norm(v)
                if n in ALIAS_DYNAMICS and col_dyn is None:
                    col_dyn = c
                if n == "IMAGEN" and col_img is None:
                    col_img = c
            if col_dyn is None:
                print("  !! %s: no se hallo columna DYNAMICS" % ws.title)
                continue

            refs = {}
            for i in range(hdr_idx + 1, len(filas)):
                row = filas[i]
                v = row[col_dyn - 1] if col_dyn - 1 < len(row) else None
                if v is None:
                    continue
                ref = str(v).replace("\xa0", " ").strip()   # TRIM obligatorio
                if ref:
                    refs[i + 1] = ref                        # fila base 1 de Excel
            tablas[ws.title] = {
                "fila_encabezado": hdr_idx + 1,
                "col_dynamics": col_dyn,
                "col_imagen": col_img,
                "refs": refs,
            }
    finally:
        wb.close()
    return tablas


# ---------------------------------------------------------------- anclajes
def leer_anclajes(z, tablas):
    """Recorre la cadena workbook -> hoja -> drawing y devuelve los anclajes."""
    wb_rels = load_rels(z, "xl/workbook.xml")
    root = ET.fromstring(z.read("xl/workbook.xml"))

    anclajes = []
    for sh in root.find("m:sheets", NS).findall("m:sheet", NS):
        nombre = sh.get("name")
        if norm(nombre) in HOJAS_IGNORADAS or nombre not in tablas:
            continue
        sheet_part = wb_rels.get(sh.get(R_ID))
        if not sheet_part:
            continue
        sh_rels = load_rels(z, sheet_part)

        drawing_part = None
        rels_root = ET.fromstring(
            z.read(posixpath.join(posixpath.dirname(sheet_part), "_rels",
                                  posixpath.basename(sheet_part) + ".rels")))
        for rel in rels_root.findall("r:Relationship", NS):
            if rel.get("Type", "").endswith("/drawing"):
                drawing_part = sh_rels.get(rel.get("Id"))
                break
        if not drawing_part:
            continue

        dw_rels = load_rels(z, drawing_part)
        dw = ET.fromstring(z.read(drawing_part))

        for anchor in list(dw):
            tag = anchor.tag.split("}")[-1]
            if tag not in ("twoCellAnchor", "oneCellAnchor", "absoluteAnchor"):
                continue
            pic = anchor.find("xdr:pic", NS)
            if pic is None:
                continue
            blip = pic.find("xdr:blipFill/a:blip", NS)
            if blip is None:
                continue
            media = dw_rels.get(blip.get(R_EMBED))
            if not media:
                continue

            frm = anchor.find("xdr:from", NS)
            if frm is None:                      # absoluteAnchor: sin celda de origen
                fila0 = col0 = None
            else:
                fila0 = int(frm.find("xdr:row", NS).text)
                col0 = int(frm.find("xdr:col", NS).text)

            anclajes.append({
                "hoja": nombre,
                "drawing": drawing_part,
                "tipo": tag,
                "fila": None if fila0 is None else fila0 + 1,   # base 0 -> base 1
                "col": None if col0 is None else col0 + 1,
                "media": media,
                "nombre_forma": (pic.find("xdr:nvPicPr/xdr:cNvPr", NS).get("name")
                                 if pic.find("xdr:nvPicPr/xdr:cNvPr", NS) is not None else ""),
            })
    return anclajes


# ---------------------------------------------------------------- principal
def main():
    if not os.path.isfile(SRC):
        sys.exit("No existe el archivo fuente: %s" % SRC)

    os.makedirs(OUT_DIR, exist_ok=True)
    for d in (IMG_DIR, DUP_DIR):
        if os.path.isdir(d):
            shutil.rmtree(d)
        os.makedirs(d)

    print("== Leyendo hojas ==")
    tablas = leer_tablas()
    for hoja, t in tablas.items():
        print("  %-6s encabezado fila %d | DYNAMICS col %d | IMAGEN col %s | %d referencias"
              % (hoja, t["fila_encabezado"], t["col_dynamics"],
                 t["col_imagen"], len(t["refs"])))

    todas_refs = []
    for hoja, t in tablas.items():
        for fila, ref in sorted(t["refs"].items()):
            todas_refs.append((hoja, fila, ref))
    refs_unicas = sorted({r for _, _, r in todas_refs})
    print("  TOTAL referencias unicas: %d" % len(refs_unicas))

    with zipfile.ZipFile(SRC, "r") as z:
        total_media = len([n for n in z.namelist() if n.startswith("xl/media/")])
        print("\n== Anclajes en xl/drawings ==")
        anclajes = leer_anclajes(z, tablas)
        por_hoja = defaultdict(int)
        for a in anclajes:
            por_hoja[a["hoja"]] += 1
        for hoja in tablas:
            print("  %-6s %d anclajes" % (hoja, por_hoja[hoja]))
        print("  TOTAL anclajes flotantes: %d" % len(anclajes))
        print("  TOTAL imagenes en xl/media: %d (incluye las 'en celda')" % total_media)

        # -------- mapeo fila -> referencia
        mapeo, huerfanas = [], []
        usadas = defaultdict(list)          # referencia -> [anclajes]

        for a in anclajes:
            t = tablas[a["hoja"]]
            ref = t["refs"].get(a["fila"]) if a["fila"] else None
            motivo = None
            if ref is None:
                motivo = ("fila %s sin referencia DYNAMICS (probable imagen de ambiente)"
                          % a["fila"])
            elif t["col_imagen"] and a["col"] != t["col_imagen"]:
                motivo = ("anclada en columna %s, no en la columna IMAGEN (%s)"
                          % (a["col"], t["col_imagen"]))
            if motivo:
                huerfanas.append({
                    "imagen_original": a["media"], "hoja": a["hoja"],
                    "fila": a["fila"], "col": a["col"],
                    "nombre_forma": a["nombre_forma"], "motivo": motivo,
                })
                continue
            usadas[ref].append(a)

        # -------- exportar
        duplicadas = []
        for ref in sorted(usadas):
            for orden, a in enumerate(usadas[ref]):
                data = z.read(a["media"])
                w, h = png_size(data)
                primero = (orden == 0)
                if primero:
                    destino_dir, nombre = IMG_DIR, "%s.png" % ref
                else:
                    destino_dir = DUP_DIR
                    nombre = "%s__dup%d.png" % (ref, orden + 1)
                    duplicadas.append({
                        "referencia": ref, "imagen_original": a["media"],
                        "archivo_destino": nombre, "hoja": a["hoja"],
                        "fila": a["fila"],
                    })
                with open(os.path.join(destino_dir, nombre), "wb") as fh:
                    fh.write(data)
                if primero:
                    mapeo.append({
                        "referencia": ref,
                        "imagen_original": a["media"],
                        "archivo_destino": nombre,
                        "hoja": a["hoja"],
                        "fila": a["fila"],
                        "ancho": w,
                        "alto": h,
                        "bytes": len(data),
                    })

    mapeo.sort(key=lambda m: (m["hoja"], m["fila"]))
    with open(MAP_JSON, "w", encoding="utf-8") as fh:
        json.dump(mapeo, fh, ensure_ascii=False, indent=2)

    cubiertas = {m["referencia"] for m in mapeo}
    sin_imagen = [r for r in refs_unicas if r not in cubiertas]

    diag = {
        "archivo_fuente": SRC,
        "total_imagenes_media": total_media,
        "total_anclajes_flotantes": len(anclajes),
        "total_mapeadas": len(mapeo),
        "referencias_unicas": len(refs_unicas),
        "referencias_cubiertas": len(cubiertas),
        "huerfanas": huerfanas,
        "duplicadas": duplicadas,
        "referencias_sin_imagen": sin_imagen,
        "por_hoja": {h: {"referencias": len(t["refs"]),
                         "anclajes": por_hoja[h],
                         "exportadas": sum(1 for m in mapeo if m["hoja"] == h)}
                     for h, t in tablas.items()},
    }
    with open(DIAG_JSON, "w", encoding="utf-8") as fh:
        json.dump(diag, fh, ensure_ascii=False, indent=2)

    # -------- informe
    print("\n== Resultado ==")
    print("  imagenes exportadas : %d  -> %s" % (len(mapeo), IMG_DIR))
    print("  referencias cubiertas: %d de %d" % (len(cubiertas), len(refs_unicas)))
    print("  huerfanas (no exportadas): %d" % len(huerfanas))
    for hu in huerfanas:
        print("     - %s  %s!%s col %s  [%s]  %s"
              % (hu["imagen_original"], hu["hoja"], hu["fila"], hu["col"],
                 hu["nombre_forma"], hu["motivo"]))
    print("  duplicadas (2+ imagenes en la misma referencia): %d" % len(duplicadas))
    for d in duplicadas:
        print("     - %s <- %s (%s!%s)" % (d["referencia"], d["imagen_original"],
                                           d["hoja"], d["fila"]))
    print("  referencias SIN imagen: %d" % len(sin_imagen))
    for r in sin_imagen:
        print("     - %s" % r)

    dims = [(m["ancho"], m["alto"]) for m in mapeo if m["ancho"]]
    if dims:
        print("  tamano PNG: min %dx%d  max %dx%d" % (
            min(d[0] for d in dims), min(d[1] for d in dims),
            max(d[0] for d in dims), max(d[1] for d in dims)))
    sin_dim = [m["archivo_destino"] for m in mapeo if not m["ancho"]]
    if sin_dim:
        print("  !! sin dimensiones legibles: %s" % sin_dim)

    print("\n  mapa        : %s" % MAP_JSON)
    print("  diagnostico : %s" % DIAG_JSON)
    print("\n  Muestra:")
    for m in mapeo[:10]:
        print("     %-18s <- %-22s %s!%d  %dx%d  %d B"
              % (m["referencia"], m["imagen_original"], m["hoja"], m["fila"],
                 m["ancho"] or 0, m["alto"] or 0, m["bytes"]))


if __name__ == "__main__":
    main()
