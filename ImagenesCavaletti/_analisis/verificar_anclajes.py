# -*- coding: utf-8 -*-
"""
Re-derivacion INDEPENDIENTE del mapeo referencia -> imagen flotante,
leyendo directamente el .xlsx (solo lectura) sin usar los JSON previos.
Sirve para contrastar mapa_flotantes.json con una segunda implementacion.
"""
import json
import re
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

XLSX = Path(r"C:\Users\jaduj\Documents\PORTAFOLIO DYNAMICS - CAVALETTI .xlsx")
OUT = Path(r"C:\Users\jaduj\Documents\GitHub\Bodhitri\ImagenesCavaletti")

NS = {
    "main": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "pr": "http://schemas.openxmlformats.org/package/2006/relationships",
    "xdr": "http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing",
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
}
RID = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
REMBED = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed"

HOJAS = ["BOLDY", "DOMOS", "BLOKS", "PIBOU", "TALK", "DUO", "INAUT", "MATCH"]


def norm(s):
    if s is None:
        return ""
    return re.sub(r"\s+", " ", str(s)).strip().upper()


def resolve(base_part, target):
    """Resuelve un Target relativo de un _rels respecto a la parte que lo declara."""
    if target.startswith("/"):
        return target.lstrip("/")
    base_dir = base_part.rsplit("/", 1)[0] if "/" in base_part else ""
    parts = (base_dir.split("/") if base_dir else []) + target.split("/")
    stack = []
    for p in parts:
        if p in ("", "."):
            continue
        if p == "..":
            if stack:
                stack.pop()
        else:
            stack.append(p)
    return "/".join(stack)


def rels_for(z, part):
    d = part.rsplit("/", 1)[0] if "/" in part else ""
    name = part.rsplit("/", 1)[-1]
    rp = (d + "/" if d else "") + "_rels/" + name + ".rels"
    out = {}
    if rp not in z.namelist():
        return out
    root = ET.fromstring(z.read(rp))
    for rel in root:
        out[rel.get("Id")] = {
            "type": rel.get("Type", "").rsplit("/", 1)[-1],
            "target": resolve(part, rel.get("Target", "")),
            "mode": rel.get("TargetMode", ""),
        }
    return out


def col_letter_to_idx(ref):
    m = re.match(r"([A-Z]+)(\d+)", ref)
    letters, row = m.group(1), int(m.group(2))
    c = 0
    for ch in letters:
        c = c * 26 + (ord(ch) - 64)
    return c - 1, row


def main():
    z = zipfile.ZipFile(XLSX, "r")

    # --- hoja -> parte xml
    wb = ET.fromstring(z.read("xl/workbook.xml"))
    wb_rels = rels_for(z, "xl/workbook.xml")
    sheet_part = {}
    for sh in wb.find("main:sheets", NS):
        sheet_part[sh.get("name")] = wb_rels[sh.get(RID)]["target"]

    # --- shared strings
    sst = []
    if "xl/sharedStrings.xml" in z.namelist():
        sroot = ET.fromstring(z.read("xl/sharedStrings.xml"))
        for si in sroot:
            sst.append("".join(t.text or "" for t in si.iter(
                "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t")))

    def cell_text(c):
        t = c.get("t")
        if t == "s":
            v = c.find("main:v", NS)
            return sst[int(v.text)] if v is not None else ""
        if t == "inlineStr":
            iss = c.find("main:is", NS)
            return "".join(x.text or "" for x in iss.iter(
                "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t")) if iss is not None else ""
        v = c.find("main:v", NS)
        return v.text if v is not None else ""

    resultado = {}
    todas_refs = []
    detalle = []

    for hoja in HOJAS:
        part = sheet_part[hoja]
        sroot = ET.fromstring(z.read(part))
        # grid: fila -> {col_idx: texto}
        grid = {}
        for row in sroot.iter("{http://schemas.openxmlformats.org/spreadsheetml/2006/main}row"):
            rn = int(row.get("r"))
            d = {}
            for c in row:
                ref = c.get("r")
                if not ref:
                    continue
                ci, _ = col_letter_to_idx(ref)
                d[ci] = cell_text(c)
            grid[rn] = d

        # fila de encabezado: contiene COSTO y PRECIO DE VENTA
        hdr_row = None
        for rn in sorted(grid):
            vals = {norm(v) for v in grid[rn].values()}
            if "COSTO" in vals and "PRECIO DE VENTA" in vals:
                hdr_row = rn
                break
        hdr = grid[hdr_row]
        col_imagen = col_id = None
        for ci, v in hdr.items():
            n = norm(v)
            if n == "IMAGEN":
                col_imagen = ci
            if n in ("DYNAMICS", "DINAMYCS", "DYNAMYCS", "DINAMICS"):
                col_id = ci

        # referencias por fila
        refs_hoja = {}
        for rn in sorted(grid):
            if rn <= hdr_row:
                continue
            val = grid[rn].get(col_id, "")
            ref = str(val).strip()
            if ref and norm(ref) not in ("DYNAMICS", "DINAMYCS"):
                refs_hoja[rn] = ref
                todas_refs.append((hoja, rn, ref))

        # drawing de la hoja
        srels = rels_for(z, part)
        dpart = None
        for rid, info in srels.items():
            if info["type"] == "drawing":
                dpart = info["target"]
        anclajes = []
        if dpart:
            droot = ET.fromstring(z.read(dpart))
            drels = rels_for(z, dpart)
            for anchor in droot:
                tag = anchor.tag.rsplit("}", 1)[-1]
                if tag not in ("twoCellAnchor", "oneCellAnchor", "absoluteAnchor"):
                    continue
                frm = anchor.find("xdr:from", NS)
                if frm is None:
                    continue
                fc = int(frm.find("xdr:col", NS).text)
                fr = int(frm.find("xdr:row", NS).text)
                blip = None
                for b in anchor.iter("{http://schemas.openxmlformats.org/drawingml/2006/main}blip"):
                    blip = b
                    break
                if blip is None:
                    continue
                emb = blip.get(REMBED)
                if emb not in drels:
                    continue
                img = drels[emb]["target"]
                anclajes.append({"col": fc, "row0": fr, "img": img})

        for a in anclajes:
            fila_excel = a["row0"] + 1
            if a["col"] != col_imagen:
                detalle.append({"hoja": hoja, "descartado": True, "col": a["col"],
                                "col_imagen": col_imagen, "fila": fila_excel, "img": a["img"]})
                continue
            ref = refs_hoja.get(fila_excel)
            if not ref:
                detalle.append({"hoja": hoja, "sin_ref": True, "fila": fila_excel, "img": a["img"]})
                continue
            if ref in resultado:
                detalle.append({"hoja": hoja, "colision": True, "ref": ref, "img": a["img"]})
            resultado[ref] = a["img"]

        print(f"{hoja:6s} hdr={hdr_row} colIMG={col_imagen} colID={col_id} "
              f"refs={len(refs_hoja)} anclajes={len(anclajes)} "
              f"en_col_imagen={sum(1 for a in anclajes if a['col']==col_imagen)}")

    z.close()

    refs_unicas = sorted({r for _, _, r in todas_refs})
    print(f"\nreferencias totales (filas)={len(todas_refs)}  unicas={len(refs_unicas)}")
    print(f"mapeadas por anclaje={len(resultado)}")
    sin = [r for r in refs_unicas if r not in resultado]
    print("sin imagen:", sin)

    # contraste con mapa_flotantes.json
    prev = {r["referencia"]: r["imagen_original"] for r in
            json.load(open(OUT / "mapa_flotantes.json", encoding="utf-8"))}
    difs = []
    for ref in sorted(set(prev) | set(resultado)):
        a = prev.get(ref)
        b = resultado.get(ref)
        if a != b:
            difs.append((ref, a, b))
    print(f"\nCONTRASTE con mapa_flotantes.json: {len(difs)} diferencias de {len(set(prev)|set(resultado))} refs")
    for d in difs[:20]:
        print("  ", d)

    json.dump({"reconstruido": resultado, "refs_unicas": refs_unicas,
               "sin_imagen": sin, "difs": difs,
               "descartes": [d for d in detalle]},
              open(OUT / "verificacion_anclajes.json", "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
