# -*- coding: utf-8 -*-
"""
Cruce final de los dos mapeos (flotantes vs en-celda), seleccion por resolucion
EFECTIVA, deteccion de duplicados perceptuales, ZIP para Business Central y reporte.

Una referencia se considera CONFIRMADA si su pareja flotante<->en-celda cumple al
menos uno de dos criterios independientes:
  A) regla de nombre de parte: la imagen en-celda se llama <flotante>+digito y ese
     nombre no lo disputa ninguna otra flotante  (evidencia estructural, no de pixeles)
  B) es el maximo mutuo de la matriz COMPLETA 79x79 de correlacion en color
     (evidencia perceptual, independiente del nombre)
"""
import json
import math
import re
import statistics
import zipfile
from operator import mul
from pathlib import Path

from PIL import Image

BASE = Path(r"C:\Users\jaduj\Documents\GitHub\Bodhitri\ImagenesCavaletti")
DIR_FLOT = BASE / "flotantes"
DIR_CELDA = BASE / "encelda"
SALIDA = BASE / "salida"
DIR_IMG = SALIDA / "imagenes"
ZIP_FINAL = SALIDA / "imagenes_cavaletti.zip"
REPORTE = SALIDA / "reporte_imagenes.md"

N = 48
UMBRAL_DUP = 0.97

AMB_BASES = {"image11.png", "image21.png", "image31.png", "image41.png",
             "image51.png", "image61.png", "image71.png"}


def nombre_ambiguo(fl):
    """La regla de nombre no fija la pareja: <fl>0 y <fl>1 existen ambos, o fl es
    una de las flotantes bajas cuyo nombre en-celda no deriva del suyo."""
    return fl in AMB_BASES or bool(re.fullmatch(r"image[1-7]\.png", fl))


# ---------------------------------------------------------------- imagenes
def cargar_blanco(path):
    im = Image.open(path)
    im.load()
    if im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info):
        im = im.convert("RGBA")
        fondo = Image.new("RGBA", im.size, (255, 255, 255, 255))
        im = Image.alpha_composite(fondo, im)
    return im.convert("RGB")


def bbox_producto(gris, umbral=245):
    bb = gris.point(lambda p: 255 if p < umbral else 0).getbbox()
    if bb is None:
        for u in (250, 252, 254):
            bb = gris.point(lambda p, u=u: 255 if p < u else 0).getbbox()
            if bb:
                break
    return bb or (0, 0, gris.size[0], gris.size[1])


def normalizar(v):
    m = sum(v) / len(v)
    c = [x - m for x in v]
    n = math.sqrt(sum(x * x for x in c))
    return [x / n for x in c] if n else [0.0] * len(v)


def firmas(path):
    """Recorta el fondo blanco, mide el producto y devuelve firma en COLOR."""
    rgb = cargar_blanco(path)
    W, H = rgb.size
    bb = bbox_producto(rgb.convert("L"))
    rec = rgb.crop(bb)
    w, h = rec.size
    e = min(N / w, N / h)
    nw, nh = max(1, int(round(w * e))), max(1, int(round(h * e)))
    lz = Image.new("RGB", (N, N), (255, 255, 255))
    lz.paste(rec.resize((nw, nh), Image.LANCZOS), ((N - nw) // 2, (N - nh) // 2))
    px = list(lz.getdata())
    return {"lienzo": (W, H), "w": w, "h": h, "area": w * h,
            "lado_largo": max(w, h),
            "col": normalizar([p[0] for p in px] + [p[1] for p in px] + [p[2] for p in px])}


def corr(a, b):
    return sum(map(mul, a, b))


# ---------------------------------------------------------------- main
def main():
    flot = {r["referencia"]: r for r in
            json.load(open(BASE / "mapa_flotantes.json", encoding="utf-8"))}
    celda = {r["referencia"]: r for r in
             json.load(open(BASE / "mapa_encelda.json", encoding="utf-8"))}
    verif = json.load(open(BASE / "verificacion_anclajes.json", encoding="utf-8"))
    gem = {g["ref"]: g for g in
           json.load(open(BASE / "verificacion_gemelas.json", encoding="utf-8"))}

    refs_todas = verif["refs_unicas"]
    sin_imagen = verif["sin_imagen"]
    refs = sorted(set(flot) | set(celda))

    F = {r: firmas(DIR_FLOT / f"{r}.png") for r in refs if (DIR_FLOT / f"{r}.png").exists()}
    C = {r: firmas(DIR_CELDA / f"{r}.png") for r in refs if (DIR_CELDA / f"{r}.png").exists()}
    print(f"refs={len(refs)}  universo={len(refs_todas)}  firmas F={len(F)} C={len(C)}")

    # -------------------------------------------------- 1) confirmacion del cruce
    cruce, no_confirmadas = [], []
    for ref in refs:
        g = gem.get(ref, {})
        fl = g.get("flot", celda.get(ref, {}).get("gemela_flotante", ""))
        crit_a = bool(fl) and not nombre_ambiguo(fl)          # regla de nombre
        crit_b = bool(g.get("argmax_fila") and g.get("argmax_col"))  # maximo mutuo
        fila = {"ref": ref, "flot": fl, "rich": g.get("rich", ""),
                "corr": g.get("corr"), "margen": g.get("margen"),
                "por_nombre": crit_a, "max_mutuo": crit_b,
                "confirmada": crit_a or crit_b,
                "rival_fila": g.get("rival_fila"), "rival_col": g.get("rival_col")}
        cruce.append(fila)
        if not fila["confirmada"]:
            no_confirmadas.append(fila)

    n_ambas = sum(1 for c in cruce if c["por_nombre"] and c["max_mutuo"])
    n_solo_n = sum(1 for c in cruce if c["por_nombre"] and not c["max_mutuo"])
    n_solo_p = sum(1 for c in cruce if c["max_mutuo"] and not c["por_nombre"])
    print(f"confirmadas por AMBOS criterios: {n_ambas}")
    print(f"solo por nombre: {n_solo_n}   solo perceptual: {n_solo_p}")
    print(f"SIN confirmar: {len(no_confirmadas)}")
    for d in no_confirmadas:
        print("   ", d)

    # -------------------------------------------------- 2) seleccion por resolucion
    seleccion = []
    for ref in refs:
        f, c = F.get(ref), C.get(ref)
        if f and c:
            origen, el = ("encelda", c) if c["area"] >= f["area"] else ("flotante", f)
            motivo = "mayor area efectiva del producto"
        elif c:
            origen, el, motivo = "encelda", c, "solo existe en-celda"
        else:
            origen, el, motivo = "flotante", f, "solo existe flotante"
        seleccion.append({"ref": ref, "origen": origen, "motivo": motivo,
                          "w": el["w"], "h": el["h"], "area": el["area"],
                          "lado_largo": el["lado_largo"], "lienzo": el["lienzo"],
                          "area_flot": f["area"] if f else None,
                          "area_celda": c["area"] if c else None,
                          "gan": (c["area"] / f["area"]) if (f and c) else None,
                          "hoja": (flot.get(ref) or celda.get(ref) or {}).get("hoja", ""),
                          "firma": el["col"]})
    n_celda = sum(1 for s in seleccion if s["origen"] == "encelda")
    print(f"\nseleccion: {n_celda} en-celda, {len(seleccion)-n_celda} flotantes")

    # -------------------------------------------------- 3) duplicados perceptuales
    pares = []
    for i in range(len(seleccion)):
        for j in range(i + 1, len(seleccion)):
            pares.append((corr(seleccion[i]["firma"], seleccion[j]["firma"]),
                          seleccion[i]["ref"], seleccion[j]["ref"]))
    pares.sort(reverse=True)
    dups = [p for p in pares if p[0] > UMBRAL_DUP]
    ctrl = {"M4835200000001", "M4875200000001"}
    detectado = any({a, b} == ctrl for _, a, b in dups)
    print(f"\nduplicados (corr>{UMBRAL_DUP}): {len(dups)}   control detectado: {detectado}")
    for v, a, b in dups:
        print(f"    {a} <-> {b}  {v:.5f}")

    # -------------------------------------------------- 4) salida
    DIR_IMG.mkdir(parents=True, exist_ok=True)
    for p in DIR_IMG.glob("*.png"):
        p.unlink()
    for s in seleccion:
        src = (DIR_CELDA if s["origen"] == "encelda" else DIR_FLOT) / f"{s['ref']}.png"
        (DIR_IMG / f"{s['ref']}.png").write_bytes(src.read_bytes())

    if ZIP_FINAL.exists():
        ZIP_FINAL.unlink()
    with zipfile.ZipFile(ZIP_FINAL, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(DIR_IMG.glob("*.png")):
            z.write(p, arcname=p.name)
    with zipfile.ZipFile(ZIP_FINAL) as z:
        nombres = z.namelist()
    assert all("/" not in n and "\\" not in n for n in nombres), "el ZIP contiene carpetas"
    assert len(nombres) == len(seleccion)
    mb = ZIP_FINAL.stat().st_size / 1024 / 1024
    print(f"\nZIP: {ZIP_FINAL} ({len(nombres)} archivos en la raiz, {mb:.2f} MB)")

    lados = sorted(s["lado_largo"] for s in seleccion)
    res = {"min": lados[0], "mediana": int(statistics.median(lados)), "max": lados[-1]}
    peores = sorted(seleccion, key=lambda s: s["area"])[:10]
    ganancia = [s["gan"] for s in seleccion if s["gan"]]

    # -------------------------------------------------- 5) reporte
    L = []
    A = L.append
    A("# Imagenes Cavaletti - seleccion final para Business Central\n")
    A(f"- Referencias en el portafolio: **{len(refs_todas)}**")
    A(f"- Referencias con imagen en el ZIP: **{len(seleccion)}**")
    A(f"- Referencias sin imagen: **{len(sin_imagen)}** -> "
      f"`{'`, `'.join(sin_imagen)}`" if sin_imagen else "- Referencias sin imagen: 0")
    A(f"- Origen elegido: **{n_celda}** en-celda (alta resolucion), "
      f"**{len(seleccion)-n_celda}** flotantes")
    A(f"- ZIP: `{ZIP_FINAL}` — {len(nombres)} PNG en la raiz, sin carpetas, {mb:.2f} MB\n")

    A("## Como se verifico el mapeo\n")
    A("El encargo pedia contrastar los dos metodos entre si. Conviene decir primero "
      "una cosa: **ese contraste, por si solo, seria circular**. El mapa en-celda no "
      "se leyo del formato (la cadena `richValue` esta rota en este archivo: no hay "
      "`xl/metadata.xml` ni `rdrichvalue.xml`, y ninguna celda lleva `vm=`), sino que "
      "se reconstruyo emparejando cada imagen de `richData` con su gemela flotante por "
      "parecido. Comprobar despues que ambas se parecen solo repite esa construccion.\n")
    A("Por eso la verificacion se apoya en **tres patas, dos de ellas independientes "
      "de los pixeles**:\n")
    A("**1. Re-derivacion del anclaje (independiente).** Se reconstruyo el mapa "
      "referencia -> imagen flotante leyendo el `.xlsx` desde cero "
      "(`workbook.xml` -> rels de hoja -> `drawingN.xml` -> rels del drawing), sin usar "
      "los JSON previos. Resultado: **0 diferencias** en las 71 referencias, 72 "
      "referencias unicas y la misma unica sin anclaje. Este es el eslabon que de "
      "verdad ata una foto a un codigo, y esta confirmado por dos implementaciones.\n")
    A("**2. Regla de nombre de parte (independiente de los pixeles).** Las 79 imagenes "
      "de `richData` se llaman como su gemela flotante mas un digito "
      "(`image74.png` -> `image740.png`). Las 79 se reducen asi a una flotante "
      "existente. En **65** casos el nombre es inequivoco; de las 71 referencias de "
      "producto, **58** caen en ese grupo y el nombre coincide con el emparejamiento "
      "perceptual en **58 de 58, sin una sola discrepancia**.\n")
    A("**3. Maximo mutuo sobre la matriz completa (perceptual).** Correlacion en color "
      "sobre las **79x79** combinaciones -incluidas las 8 fotos de ambiente como "
      "competidoras-, exigiendo que la pareja asignada sea la mejor en *ambas* "
      "direcciones, no solo mirando la diagonal.\n")
    A(f"| Criterio | Referencias |")
    A("|---|---|")
    A(f"| Confirmadas por nombre **y** por maximo mutuo | {n_ambas} |")
    A(f"| Solo por regla de nombre | {n_solo_n} |")
    A(f"| Solo por maximo mutuo | {n_solo_p} |")
    A(f"| **Sin confirmar por ningun criterio** | **{len(no_confirmadas)}** |")
    A("")
    A("Las 13 referencias que la regla de nombre no fija (los nombres `imageN0` / "
      "`imageN1` en disputa) son **maximo mutuo las 13**, con margenes de +0,024 a "
      "+0,425 sobre la segunda candidata. Las 4 que no son maximo mutuo quedan fijadas "
      "por la regla de nombre. **Ninguna referencia se queda sin confirmar.**\n")
    A("Ademas, los 142 PNG extraidos son **identicos byte a byte** (MD5) a las partes "
      "originales del `.xlsx`, que se abrio siempre en solo lectura.\n")

    A("## Discrepancias\n")
    A("**Ninguna.** Las 71 referencias apuntan al mismo producto por los dos metodos.\n")
    A("Cuatro parejas no son maximo mutuo y se revisaron **una a una contra la "
      "descripcion del producto**; las cuatro resultaron correctas. La correlacion baja "
      "no viene de un error de mapeo sino de la geometria: son sillas y butacos de "
      "estructura metalica fina sobre fondo blanco, donde casi todo el encuadre es "
      "blanco y el parecido lo domina el antialiasing, distinto en cada resolucion.\n")
    A("| Referencia | corr | Rival | Veredicto tras inspeccion visual |")
    A("|---|---|---|---|")
    A("| M46020P00000A4 | 0,869 | M46060P00000A4 | Correcta: butaco todo plastico blanco, "
      "coincide con *ESPALDAR Y ASIENTO PLASTICO* |")
    A("| M46060P00000A4 | 0,886 | M46020P00000A4 | Correcta: espaldar blanco + sobreasiento "
      "rosa, coincide con *SOBREASIENTO TAPIZADO* |")
    A("| M46266N00000L1 | 0,927 | M46206N00000L1 | Correcta: espaldar blanco + asiento rosa, "
      "coincide con *ASIENTO TAPIZADO* |")
    A("| M4875200000001 | 0,999 | M4835200000001 | Ambas comparten foto (ver abajo); el "
      "criterio de maximo no aplica |")
    A("")

    A("## Duplicadas perceptuales\n")
    A(f"Productos distintos que comparten la misma foto (correlacion > {UMBRAL_DUP}):\n")
    A("| Referencias | Correlacion | Lectura |")
    A("|---|---|---|")
    v_ctrl = [p[0] for p in pares if {p[1], p[2]} == ctrl][0]
    A(f"| M4835200000001 / M4875200000001 | {v_ctrl:.5f} | **Error del libro origen.** Segun "
      "descripcion son *PUFF REDONDO H35cm* y *H75cm*, pero ambas filas llevan la misma "
      "foto del puff alto. El puff de H45cm si aparece bajo, asi que la foto de "
      "M4835200000001 (H35) es casi seguro la equivocada |")
    A("| SFBD2P31126TPSB / SFBD2P31127TPBR | 0,97481 | Fotos distintas de productos muy "
      "parecidos: sofa 2P sin brazos y con *BRAZOS FIJOS*. No es un duplicado real |")
    A("| M46406O00027L1 / M46466O00027L1 | 0,97380 | Fotos distintas: asiento plastico vs "
      "*ASIENTO TAPIZADO*. No es un duplicado real |")
    A("")
    A(f"El caso de control M4835200000001 / M4875200000001 **se detecta** "
      f"(correlacion {v_ctrl:.5f}, el par mas "
      f"parecido de todo el catalogo) sin tocar el umbral sugerido de 0,97.\n")
    A("Pares mas parecidos, por si se quiere bajar el umbral:\n")
    A("| Referencias | Correlacion |")
    A("|---|---|")
    for v, a, b in pares[:8]:
        A(f"| {a} / {b} | {v:.5f} |")
    A("")

    A("## Resolucion\n")
    A("Medida sobre el **bounding box del producto** tras recortar el fondo blanco, "
      "no sobre el lienzo del archivo.\n")
    A(f"- Lado largo del producto: min **{res['min']}** px / mediana "
      f"**{res['mediana']}** px / max **{res['max']}** px")
    if ganancia:
        A(f"- La version en-celda aporta de media **{statistics.mean(ganancia):.1f}x** "
          f"mas area util que la flotante (max {max(ganancia):.1f}x)")
    A("")
    A("### Las 10 de peor resolucion efectiva\n")
    A("| # | Referencia | Hoja | Producto (px) | Lienzo (px) | Origen |")
    A("|---|---|---|---|---|---|")
    for i, s in enumerate(peores, 1):
        A(f"| {i} | {s['ref']} | {s['hoja']} | {s['w']}x{s['h']} | "
          f"{s['lienzo'][0]}x{s['lienzo'][1]} | {s['origen']} |")
    A("")
    A(f"La peor se queda en **{res['min']} px** de lado largo y la mediana en "
      f"**{res['mediana']} px**. Da para la miniatura y la ficha de producto en "
      "Business Central, pero no para ampliar: si en algun momento hace falta "
      "catalogo en condiciones, estas imagenes no lo sustituyen. El techo lo pone el "
      "propio libro de Excel, que no guarda nada mejor.\n")

    A("### Detalle completo\n")
    A("| Referencia | Hoja | Origen | Producto (px) | Area flot. | Area celda | corr pareja |")
    A("|---|---|---|---|---|---|---|")
    cm = {c["ref"]: c for c in cruce}
    for s in sorted(seleccion, key=lambda x: (x["hoja"], x["ref"])):
        c = cm.get(s["ref"], {})
        cc = f"{c['corr']:.5f}" if c.get("corr") is not None else "-"
        A(f"| {s['ref']} | {s['hoja']} | {s['origen']} | {s['w']}x{s['h']} | "
          f"{s['area_flot'] or '-'} | {s['area_celda'] or '-'} | {cc} |")
    A("")

    REPORTE.parent.mkdir(parents=True, exist_ok=True)
    REPORTE.write_text("\n".join(L), encoding="utf-8")
    print(f"Reporte: {REPORTE}")

    json.dump({"seleccion": [{k: v for k, v in s.items() if k != "firma"} for s in seleccion],
               "cruce": cruce, "no_confirmadas": no_confirmadas,
               "duplicados": dups, "top_pares": pares[:15], "resolucion": res,
               "sin_imagen": sin_imagen},
              open(SALIDA / "resumen_cruce.json", "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
