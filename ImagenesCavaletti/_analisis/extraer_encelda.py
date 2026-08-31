# -*- coding: utf-8 -*-
"""
Extrae las imagenes "EN CELDA" (xl/richData/) del portafolio Cavaletti y las
renombra con su codigo DYNAMICS.

HALLAZGO IMPORTANTE (ver bloque de diagnostico que imprime este script):
la cadena documentada del mecanismo "Colocar imagen en celda" esta ROTA en este
archivo. Sobrevive el ultimo eslabon (richValueRel.xml -> xl/media) pero faltan
por completo las partes que unen la CELDA con el rich value:
    - NO existe xl/metadata.xml
    - NO existe xl/richData/rdrichvalue.xml  (ni richValue.xml, ni
      rdRichValueStructure.xml, ni rdRichValueTypes.xml)
    - NINGUNA celda de ninguna hoja tiene el atributo vm="N"
    - NINGUNA celda es de tipo error (t="e"); las celdas de la columna IMAGEN
      estan literalmente vacias: <c r="C10" s="31"/>
Por tanto es IMPOSIBLE recorrer  celda -> vm -> metadata -> richValue -> rel.

Reconstruccion usada en su lugar (no es una invencion: es verificable y se mide):
las 158 imagenes de xl/media se reparten en dos conjuntos disjuntos de 79 que son
el MISMO catalogo fotografico a dos resoluciones:
    - 79 flotantes, referenciadas desde xl/drawings/drawingN.xml, que SI
      conservan su ancla <xdr:from> a una (columna, fila) concreta.
    - 79 "en celda", referenciadas desde xl/richData/richValueRel.xml, huerfanas.
Se empareja cada imagen en-celda con su gemela flotante por CONTENIDO de imagen
(correlacion de Pearson sobre RGB) y se hereda la fila del ancla de la flotante,
de donde se lee el codigo DYNAMICS. El emparejamiento se resuelve con asignacion
optima global (algoritmo hungaro) para garantizar biyeccion 1:1.

Solo lectura sobre el .xlsx original. Requiere openpyxl y Pillow.
"""
import io
import json
import math
import os
import re
import struct
import sys
import zipfile
import xml.etree.ElementTree as ET

import openpyxl
from PIL import Image

SRC = r'C:\Users\jaduj\Documents\PORTAFOLIO DYNAMICS - CAVALETTI .xlsx'
OUT_DIR = r'C:\Users\jaduj\Documents\GitHub\Bodhitri\ImagenesCavaletti'
IMG_DIR = os.path.join(OUT_DIR, 'encelda')
JSON_PATH = os.path.join(OUT_DIR, 'mapa_encelda.json')

SHEETS = ['BOLDY', 'DOMOS', 'BLOKS', 'PIBOU', 'TALK', 'DUO', 'INAUT', 'MATCH']
DYN_HEADERS = {'DYNAMICS', 'DINAMYCS', 'DINAMICS', 'DYNAMYCS'}
COL_IMAGEN = 2  # indice 0-based de la columna C, donde vive la foto de producto

NS_XDR = '{http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing}'
NS_A = '{http://schemas.openxmlformats.org/drawingml/2006/main}'
NS_R = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'


def norm(s):
    if s is None:
        return ''
    return re.sub(r'\s+', ' ', str(s)).strip().upper()


# ---------------------------------------------------------------- diagnostico
def diagnosticar(z):
    """Comprueba si la cadena richValue esta completa. Devuelve (ok, problemas)."""
    names = set(z.namelist())
    prob = []
    tiene_rel = 'xl/richData/richValueRel.xml' in names
    metadata = [n for n in names if re.search(r'metadata', n, re.I)]
    rdrich = [n for n in names if re.search(r'richData/(rdrichvalue|richvalue|rdRichValue)', n, re.I)
              and not n.endswith('richValueRel.xml') and '_rels' not in n]
    vm_total = 0
    err_total = 0
    for n in sorted(names):
        if re.match(r'xl/worksheets/sheet\d+\.xml$', n):
            d = z.read(n).decode('utf8')
            vm_total += len(re.findall(r'\bvm="\d+"', d))
            err_total += len(re.findall(r'<c [^>]*t="e"', d))

    print('--- DIAGNOSTICO DE LA CADENA richValue ---')
    print('  richValueRel.xml presente ......... %s' % tiene_rel)
    print('  partes *metadata* presentes ....... %s' % (metadata or 'NINGUNA'))
    print('  partes rdrichvalue/richValue ...... %s' % (rdrich or 'NINGUNA'))
    print('  celdas con atributo vm="N" ........ %d' % vm_total)
    print('  celdas de tipo error t="e" ........ %d' % err_total)

    ok = bool(metadata) and bool(rdrich) and vm_total > 0
    if not ok:
        if not metadata:
            prob.append('No existe xl/metadata.xml: se pierde el vinculo vm -> indice de richValue.')
        if not rdrich:
            prob.append('No existe xl/richData/rdrichvalue.xml (ni richValue.xml ni '
                        'rdRichValueStructure.xml): se pierde el vinculo richValue -> indice de richValueRel.')
        if vm_total == 0:
            prob.append('Ninguna celda de ninguna hoja lleva el atributo vm="N"; las celdas de la '
                        'columna IMAGEN estan vacias (p.ej. <c r="C10" s="31"/>), no son celdas de '
                        'error #VALUE!. El vinculo celda -> imagen no existe en el archivo.')
        prob.append('Conclusion: el archivo SI uso el mecanismo richValue (sobrevive '
                    'richValueRel.xml con 79 imagenes de alta resolucion, declarado en '
                    'xl/_rels/workbook.xml.rels con el tipo .../2022/10/relationships/richValueRel), '
                    'pero la cadena esta rota: las partes de enlace fueron eliminadas en algun '
                    'guardado. Las 79 imagenes en celda quedaron huerfanas dentro del paquete.')
    print('  => cadena documentada recorrible: %s' % ok)
    print()
    return ok, prob


# ------------------------------------------------------- hoja/fila -> codigo
def leer_referencias():
    """(hoja, fila) -> codigo DYNAMICS, localizando encabezados por nombre."""
    wb = openpyxl.load_workbook(SRC, read_only=True, data_only=True)
    row2ref = {}
    detalle = {}
    for sn in SHEETS:
        ws = wb[sn]
        rows = list(ws.iter_rows(min_row=1, max_row=80, max_col=12, values_only=True))
        hdr_i = None
        for i, r in enumerate(rows):
            vals = [norm(v) for v in r]
            if any(v == 'COSTO' for v in vals) and any('PRECIO DE VENTA' in v for v in vals if v):
                hdr_i = i
                break
        if hdr_i is None:
            raise RuntimeError('No se localizo la fila de encabezado en la hoja %s' % sn)
        hdr = [norm(v) for v in rows[hdr_i]]
        dyn_c = next((ci for ci, v in enumerate(hdr) if v in DYN_HEADERS), None)
        if dyn_c is None:
            raise RuntimeError('No se localizo la columna DYNAMICS en la hoja %s (encabezados: %s)' % (sn, hdr))
        n = 0
        for i in range(hdr_i + 1, len(rows)):
            fila = rows[i]
            v = fila[dyn_c] if dyn_c < len(fila) else None
            if v is None:
                continue
            ref = str(v).strip()  # TRIM: hay referencias con espacios sobrantes
            if not ref:
                continue
            row2ref[(sn, i + 1)] = ref
            n += 1
        detalle[sn] = (hdr_i + 1, hdr[dyn_c], n)
    wb.close()
    return row2ref, detalle


# ------------------------------------------------ anclas de imagenes flotantes
def leer_anclas(z):
    """nombre de media flotante -> (hoja, columna, fila)."""
    wbrels = z.read('xl/_rels/workbook.xml.rels').decode('utf8')
    rid2target = dict(re.findall(r'Id="(rId\d+)"[^>]*Target="(worksheets/sheet\d+\.xml)"', wbrels))
    wbxml = z.read('xl/workbook.xml').decode('utf8')
    part2name = {}
    for name, rid in re.findall(r'<sheet name="([^"]+)"[^>]*r:id="(rId\d+)"', wbxml):
        if rid in rid2target:
            part2name['xl/' + rid2target[rid]] = name

    anclas = {}
    nombres = set(z.namelist())
    for part, sname in part2name.items():
        relp = part.replace('worksheets/', 'worksheets/_rels/') + '.rels'
        if relp not in nombres:
            continue
        m = re.search(r'Target="\.\./(drawings/drawing\d+\.xml)"', z.read(relp).decode('utf8'))
        if not m:
            continue
        dpart = 'xl/' + m.group(1)
        drels = z.read(dpart.replace('drawings/', 'drawings/_rels/') + '.rels').decode('utf8')
        rid2img = dict(re.findall(r'Id="(rId\d+)"[^>]*Target="\.\./media/([^"]+)"', drels))
        for anch in ET.fromstring(z.read(dpart)):
            frm = anch.find(NS_XDR + 'from')
            if frm is None:
                continue
            col = int(frm.find(NS_XDR + 'col').text)
            row = int(frm.find(NS_XDR + 'row').text) + 1  # 0-based -> 1-based
            blip = anch.find('.//' + NS_A + 'blip')
            if blip is None:
                continue
            img = rid2img.get(blip.get(NS_R + 'embed'))
            if img:
                anclas[img] = (sname, col, row)
    return anclas


def leer_encelda(z):
    """Lista ordenada de imagenes referenciadas desde richValueRel.xml."""
    rels = z.read('xl/richData/_rels/richValueRel.xml.rels').decode('utf8')
    rid2img = dict(re.findall(r'Id="(rId\d+)"[^>]*Target="\.\./media/([^"]+)"', rels))
    rv = z.read('xl/richData/richValueRel.xml').decode('utf8')
    return [rid2img[r] for r in re.findall(r'<rel r:id="(rId\d+)"\s*/>', rv) if r in rid2img]


# ------------------------------------------------------- emparejado por imagen
def cargar(z, name):
    im = Image.open(io.BytesIO(z.read('xl/media/' + name))).convert('RGBA')
    fondo = Image.new('RGBA', im.size, (255, 255, 255, 255))
    return Image.alpha_composite(fondo, im).convert('RGB')


def vector_grueso(im, n=32):
    """Rasgo barato preservando la relacion de aspecto (letterbox sobre blanco)."""
    w, h = im.size
    esc = n / max(w, h)
    nw, nh = max(1, round(w * esc)), max(1, round(h * esc))
    lienzo = Image.new('RGB', (n, n), (255, 255, 255))
    lienzo.paste(im.resize((nw, nh), Image.LANCZOS), ((n - nw) // 2, (n - nh) // 2))
    px = [v for p in lienzo.getdata() for v in p]
    m = sum(px) / len(px)
    sd = math.sqrt(sum((x - m) ** 2 for x in px) / len(px)) or 1.0
    return [(x - m) / sd for x in px]


def pearson_fino(a, b):
    """Metrica exacta: se lleva 'a' al tamano nativo de 'b' y se correlaciona en RGB."""
    A = a.resize(b.size, Image.LANCZOS)
    pa = [v for p in A.getdata() for v in p]
    pb = [v for p in b.getdata() for v in p]
    n = len(pa)
    ma, mb = sum(pa) / n, sum(pb) / n
    num = sa = sb = 0.0
    for x, y in zip(pa, pb):
        dx, dy = x - ma, y - mb
        num += dx * dy
        sa += dx * dx
        sb += dy * dy
    den = math.sqrt(sa * sb)
    return num / den if den else 0.0


def hungaro(coste):
    """Asignacion optima (minimiza). O(n^3), JV/Kuhn-Munkres con potenciales."""
    n, m = len(coste), len(coste[0])
    INF = float('inf')
    u = [0.0] * (n + 1)
    v = [0.0] * (m + 1)
    p = [0] * (m + 1)
    way = [0] * (m + 1)
    for i in range(1, n + 1):
        p[0] = i
        j0 = 0
        minv = [INF] * (m + 1)
        used = [False] * (m + 1)
        while True:
            used[j0] = True
            i0 = p[j0]
            delta = INF
            j1 = -1
            for j in range(1, m + 1):
                if not used[j]:
                    cur = coste[i0 - 1][j - 1] - u[i0] - v[j]
                    if cur < minv[j]:
                        minv[j] = cur
                        way[j] = j0
                    if minv[j] < delta:
                        delta = minv[j]
                        j1 = j
            for j in range(m + 1):
                if used[j]:
                    u[p[j]] += delta
                    v[j] -= delta
                else:
                    minv[j] -= delta
            j0 = j1
            if p[j0] == 0:
                break
        while True:
            j1 = way[j0]
            p[j0] = p[j1]
            j0 = j1
            if j0 == 0:
                break
    res = [-1] * n
    for j in range(1, m + 1):
        if p[j]:
            res[p[j] - 1] = j - 1
    return res


def png_dims(b):
    w, h = struct.unpack('>II', b[16:24])
    return w, h


def main():
    os.makedirs(IMG_DIR, exist_ok=True)
    z = zipfile.ZipFile(SRC)  # solo lectura, el original no se toca

    cadena_ok, problemas = diagnosticar(z)

    row2ref, detalle = leer_referencias()
    print('--- REFERENCIAS POR HOJA ---')
    for sn in SHEETS:
        hr, hn, n = detalle[sn]
        print('  %-6s fila encabezado=%-2d  columna id="%s"  refs=%d' % (sn, hr, hn, n))
    print('  TOTAL referencias: %d (unicas: %d)' % (len(row2ref), len(set(row2ref.values()))))
    print()

    anclas = leer_anclas(z)
    flotantes = sorted(anclas)
    encelda = leer_encelda(z)
    print('--- CONJUNTOS DE IMAGENES ---')
    print('  media total ....................... %d' % len([n for n in z.namelist() if n.startswith('xl/media/')]))
    print('  flotantes (drawings, con ancla) ... %d' % len(flotantes))
    print('  en celda (richValueRel) ........... %d' % len(encelda))
    print('  solapamiento entre conjuntos ...... %d' % len(set(flotantes) & set(encelda)))
    en_col_c = [f for f in flotantes if anclas[f][1] == COL_IMAGEN]
    print('  flotantes en columna C (producto) . %d' % len(en_col_c))
    print('  flotantes en columna B (familia) .. %d' % (len(flotantes) - len(en_col_c)))
    print()

    if len(flotantes) != len(encelda):
        problemas.append('Los conjuntos flotante (%d) y en-celda (%d) no tienen el mismo tamano; '
                         'el emparejamiento 1:1 no es aplicable.' % (len(flotantes), len(encelda)))

    # --- emparejado contenido a contenido -----------------------------------
    print('--- EMPAREJADO POR CONTENIDO ---')
    ims_r = {n: cargar(z, n) for n in encelda}
    ims_f = {n: cargar(z, n) for n in flotantes}
    vr = {n: vector_grueso(im) for n, im in ims_r.items()}
    vf = {n: vector_grueso(im) for n, im in ims_f.items()}

    K = 6
    NEG = -2.0
    S = []
    for rn in encelda:
        a = vr[rn]
        grueso = sorted(((sum(x * y for x, y in zip(a, vf[fn])) / len(a), fn) for fn in flotantes),
                        reverse=True)[:K]
        fila = [NEG] * len(flotantes)
        for _, fn in grueso:
            fila[flotantes.index(fn)] = pearson_fino(ims_r[rn], ims_f[fn])
        S.append(fila)

    asg = hungaro([[-s for s in fila] for fila in S])
    pares = [(encelda[i], flotantes[asg[i]], S[i][asg[i]]) for i in range(len(encelda))]
    puntajes = sorted(p[2] for p in pares)
    biyectivo = len(set(p[1] for p in pares)) == len(pares)
    print('  biyectivo 1:1 ..................... %s' % biyectivo)
    print('  correlacion minima ................ %.5f' % puntajes[0])
    print('  correlacion mediana ............... %.5f' % puntajes[len(puntajes) // 2])
    bajos = [p for p in pares if p[2] < 0.99]
    print('  pares con correlacion < 0.99 ...... %d' % len(bajos))
    for a, b, s in sorted(bajos, key=lambda t: t[2]):
        print('      %-15s <- %-15s  %.5f' % (b, a, s))
    if puntajes[0] < 0.97:
        problemas.append('Hay al menos un emparejamiento con correlacion baja (%.4f); revisar a mano.'
                         % puntajes[0])
    if not biyectivo:
        problemas.append('El emparejamiento no resulto biyectivo.')
    print()

    # --- salida --------------------------------------------------------------
    mapa = []
    huerfanas = []
    for rn, fn, score in pares:
        hoja, col, fila = anclas[fn]
        ref = row2ref.get((hoja, fila))
        if col != COL_IMAGEN or not ref:
            motivo = ('imagen de familia anclada en la columna B de la hoja %s (fila %d), no es foto de producto'
                      % (hoja, fila)) if col != COL_IMAGEN else \
                     ('la fila %d de %s no tiene codigo DYNAMICS' % (fila, hoja))
            huerfanas.append({'imagen': rn, 'gemela_flotante': fn, 'motivo': motivo})
            continue
        datos = z.read('xl/media/' + rn)
        w, h = png_dims(datos)
        destino = ref + '.png'
        with open(os.path.join(IMG_DIR, destino), 'wb') as fh:
            fh.write(datos)
        mapa.append({
            'referencia': ref,
            'imagen_original': rn,
            'archivo_destino': destino,
            'hoja': hoja,
            'fila': fila,
            'ancho': w,
            'alto': h,
            'bytes': len(datos),
            'gemela_flotante': fn,
            'correlacion': round(score, 6),
        })

    mapa.sort(key=lambda d: (SHEETS.index(d['hoja']), d['fila']))
    with open(JSON_PATH, 'w', encoding='utf8') as fh:
        json.dump(mapa, fh, ensure_ascii=False, indent=2)

    refs_todas = sorted(set(row2ref.values()))
    cubiertas = sorted(set(d['referencia'] for d in mapa))
    sin_imagen = sorted(set(refs_todas) - set(cubiertas))

    dup = len(mapa) - len(set(d['referencia'] for d in mapa))
    if dup:
        problemas.append('%d referencias recibieron mas de una imagen (colision de nombre de archivo).' % dup)

    print('--- RESULTADO ---')
    print('  imagenes en celda totales ......... %d' % len(encelda))
    print('  mapeadas a una referencia ......... %d' % len(mapa))
    print('  referencias cubiertas ............. %d de %d' % (len(cubiertas), len(refs_todas)))
    print('  huerfanas ......................... %d' % len(huerfanas))
    for h in huerfanas:
        print('      %-15s (gemela %s) %s' % (h['imagen'], h['gemela_flotante'], h['motivo']))
    print('  referencias sin imagen ............ %s' % (sin_imagen or 'ninguna'))
    print('  carpeta ........................... %s' % IMG_DIR)
    print('  json .............................. %s' % JSON_PATH)
    if problemas:
        print('\n--- PROBLEMAS ---')
        for p in problemas:
            print('  * %s' % p)

    escritos = [f for f in os.listdir(IMG_DIR) if f.lower().endswith('.png')]
    print('\n  PNG escritos en disco: %d' % len(escritos))
    z.close()


if __name__ == '__main__':
    main()
