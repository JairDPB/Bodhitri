# Imágenes de productos: Excel → Business Central

Dos piezas que resuelven un mismo flujo:

```
Excel con imágenes  →  <ID>.png  →  imagenes.zip  →  Business Central  →  ficha del producto
        │                                                    │
   extraer_imagenes_excel.py                    page 50101 "BDT Importar Img Items"
        (este repo)                                  (proyecto Formatos Bodhitri)
```

---

## 1. `extraer_imagenes_excel.py`

Extrae las imágenes de un Excel, las renombra con el ID del producto y las
empaqueta en un ZIP.

**Funciona con cualquier `.xlsx`**: no hay rutas, hojas ni columnas fijas en el
código. Todo se localiza por nombre de encabezado y se puede sobreescribir por
línea de comandos.

```bash
pip install openpyxl
python extraer_imagenes_excel.py libro.xlsx
```

| Parámetro | Para qué |
|---|---|
| `--col-id` | Nombre(s) de la columna con el ID. Por defecto prueba `DYNAMICS`, `DINAMYCS`, `ID`, `CODIGO`, `REFERENCIA`, `SKU`, `NO.`… |
| `--col-imagen` | Columna donde están las imágenes. Descarta las ancladas en otras columnas (logos, fotos de ambiente). Se autodetecta con `IMAGEN`, `FOTO`, `IMAGE`… |
| `--hojas` | Hojas a procesar, separadas por coma. Por defecto todas. |
| `--fila-encabezado` | Fila del encabezado si no se quiere autodetectar. |
| `--salida` / `--zip` | Carpeta y nombre del ZIP. |
| `--alta-resolucion` | Recupera las copias grandes que algunos libros guardan «en celda». Requiere Pillow. |
| `--dry-run` | Solo informa, no escribe nada. |

Salida: `salida/imagenes/<ID>.png`, `salida/imagenes.zip` y `salida/reporte.md`.

### Cómo encuentra cada cosa

1. Recorre las hojas del libro.
2. En cada una busca la fila de encabezado: la primera que contenga alguno de los
   nombres de columna de ID.
3. Localiza también la columna de imagen.
4. Lee los anclajes de `xl/drawings`: cada imagen flotante declara sobre qué celda
   está colocada.
5. Con la fila del anclaje lee el ID de esa fila y renombra la imagen.

### Dos trampas que resuelve

**Fotos decorativas.** Muchos libros tienen un logo o una foto de ambiente anclada
sobre una fila que *sí* tiene producto. Mapear solo por fila sobrescribiría la foto
real. Por eso, cuando se conoce la columna de imagen, se exige que el anclaje caiga
en ella. En el libro de Cavaletti esto salvó **8 imágenes de producto**.

**Encabezados irregulares.** La fila de encabezado no tiene por qué ser la misma en
todas las hojas, ni el nombre de la columna estar bien escrito. En el libro de
Cavaletti el encabezado está en la fila 8 en tres hojas y en la 9 en las otras cinco,
y la columna del ID se llama `DINAMYCS` en unas y `DYNAMICS` en otras. El script
acepta ambas grafías y detecta la fila por hoja.

### Sobre `--alta-resolucion`

Algunos libros guardan **dos copias** de cada foto: la flotante (pequeña, con el
anclaje) y otra «en celda» de más resolución bajo `xl/richData`.

La cadena que une la celda con la imagen grande (`metadata` → `richValue`) se pierde
con facilidad al guardar. Cuando eso pasa —y es lo que ocurre en el libro de
Cavaletti— las imágenes grandes quedan huérfanas y **no hay forma de saber a qué
producto pertenecen leyendo el formato**.

Este modo las recupera **por parecido**: compara cada imagen grande con las pequeñas
ya mapeadas y se queda con su gemela. Es una inferencia, no un dato del archivo. Por
eso solo se aplica si se pide, y solo acepta un emparejamiento cuando la similitud es
muy alta **y además es mutua** — si dos productos se disputan la misma imagen grande,
conserva la pequeña en vez de arriesgarse.

> En el libro de Cavaletti recupera 66 de 71. Las 5 restantes se quedan en baja
> resolución porque el emparejamiento no es concluyente. Verificado contra una
> extracción forense independiente: **0 discrepancias** en las 66.

---

## 2. La página AL

Está en el proyecto **Formatos Bodhitri**:
`Setup/BDTImportarImgItems.Page.al` → `page 50101 "BDT Importar Img Items"`.

En el ERP: *Importar Imágenes de Productos (ZIP)*.

Sube el ZIP, lo descomprime en el servidor con `Codeunit "Data Compression"`, y por
cada archivo toma el nombre (sin extensión ni ruta) como `No.` de producto:

- Si el producto **existe** → le asigna la imagen.
- Si **no existe** y está activa la opción *«Crear productos que no existan»* → lo crea
  y luego le asigna la imagen.
- Si no existe y la opción está desactivada → lo cuenta como no encontrado.

Para crear productos hay que informar cuatro valores en la propia página: grupo
contable de producto general, grupo de registro de inventario, grupo de registro de
IVA y unidad de medida base. Se comprueban **antes** de subir el ZIP, para no
esperar a que suba varios MB y fallar después.

> **Por qué esos cuatro son obligatorios.** Sin ellos el producto se crea, pero al
> primer pedido de venta `SalesLine.CopyFromItem` ejecuta `TestField` sobre el grupo
> contable y sobre el de inventario, y Business Central lo rechaza. Un maestro creado
> sin ellos es un maestro invendible.

El resultado se desglosa en: importadas · productos creados · no encontrados · ya
tenían imagen · duplicados en el ZIP · omitidos · fallos (con el motivo real).

---

## 3. Estructura del repo

| Ruta | Qué es |
|---|---|
| `extraer_imagenes_excel.py` | **El script.** Genérico, con parámetros. |
| `salida/imagenes_cavaletti.zip` | El ZIP del portafolio Cavaletti: 71 PNG listos para subir. |
| `salida/imagenes/` | Los mismos 71 PNG sueltos. |
| `salida/reporte_imagenes.md` | Informe de la extracción de Cavaletti. |
| `_analisis/` | Scripts forenses de un solo uso, del análisis que hizo falta para entender este libro en concreto. **No son reutilizables** (rutas fijas, sin parámetros). Se conservan como evidencia. |

---

## 4. Resultado sobre el portafolio Cavaletti

**71 de 72 referencias** con imagen. La que falta es `M2620500101009`
(ELEMENTO DE UNIÓN BLOKZ): no tiene imagen en el Excel de origen.

Dos cosas que conviene revisar con el área de producto:

- **`M4835200000001`** (puff PIBOU redondo **H35 cm**) lleva la foto de un puff
  **alto**, la misma que `M4875200000001` (H75 cm). Es un error del Excel de origen,
  no de la extracción: en el libro ambas filas apuntan a la misma imagen, en los dos
  juegos de fotos.
- **Resolución**: el producto ocupa una mediana de 179 px de lado largo. Sirve para la
  ficha del producto y la miniatura; no da para ampliar ni para material impreso. El
  techo lo pone el propio libro — no guarda nada mejor.
