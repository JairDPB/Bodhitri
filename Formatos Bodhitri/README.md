# Formatos Bodhitrí

Extensión de **Microsoft Dynamics 365 Business Central** (AL) que personaliza el
formato de impresión de la **Cotización de Venta** para mostrar la **imagen del
producto** en cada línea del documento.

| | |
|---|---|
| **Nombre** | Formatos Bodhitri |
| **Editor** | Bodhitri |
| **App ID** | `2d3d5c14-8267-4d43-b57d-115b44f8bbae` |
| **Versión** | 1.0.0.0 |
| **Plataforma / Aplicación** | BC v27 (`application 27.0.0.0`, `runtime 16.0`) |
| **Rango de objetos** | `50100`–`50149` |
| **Entorno** | Microsoft Cloud **Sandbox** (SaaS) — `SandboxBH` |

---

## Objetivo

El reporte que imprime la cotización de venta en el entorno es el
**Report `50201 "LyL Rep.CotizacionVenta"`**, que **no** es estándar de Microsoft:
pertenece a la extensión de terceros **Ezgo Fields** (LyL Consultores). Como no se
dispone del código fuente de esa extensión, este proyecto **extiende** dicho reporte
(sin modificarlo) para:

1. Agregar al dataset la imagen del producto (`Item.Picture`) por línea.
2. Aportar un layout RDLC propio (versionado en este repositorio) que muestra esa
   imagen en una columna nueva de la tabla de líneas.

---

## Dependencias

| Extensión | Editor | App ID | Versión |
|---|---|---|---|
| **Ezgo Fields** | LyL Consultores | `c2c772dd-e8d0-4698-bcea-def09552237b` | 1.0.0.84 |

> Contiene el `Report 50201 "LyL Rep.CotizacionVenta"` (extensible). Es una extensión
> **PTE**; sus símbolos se obtienen con `AL: Download Symbols` (no incluye código fuente).
>
> La dependencia previa *"D365LATAM Formatos Personalizados"* se **eliminó**: no contenía
> el reporte de cotización (sus reportes son 50910–50925, de facturación electrónica).

---

## Estructura del proyecto

```
Formatos Bodhitri/
├─ app.json                              # Manifiesto: dependencias, rango de IDs, runtime
├─ Reports Code/
│  └─ CotizacionVenta.al                 # reportextension 50100 (lógica + layout)
├─ Reports/
│  └─ Cotización Venta Ezgo.rdl          # Layout RDLC (versionado en la app)
├─ Setup/
│  ├─ BDTBuscarAppObjeto.Page.al         # page 50149: utilidad de diagnóstico
│  └─ BDTImportarImgItems.Page.al        # page 50101: carga masiva de imágenes (ZIP)
└─ README.md
```

> **Importante:** el `.al` (objetos) compila dentro del `.app`; el `.rdl` es un **recurso**
> referenciado por el objeto AL. En AL las carpetas son organizativas: el compilador
> escanea todos los `.al` sin importar la carpeta.

---

## Objetos incluidos

### `reportextension 50100 "Cotizacion Venta Img"` → extiende `"LyL Rep.CotizacionVenta"`
Archivo: [`Reports Code/CotizacionVenta.al`](Reports%20Code/CotizacionVenta.al)

- **dataset** → `add(Line)`: agrega las columnas
  - `ItemPicture_Line` → imagen del producto en Base64.
  - `ItemPictureMime_Line` → tipo MIME real de la imagen.
- **rendering** → publica el layout **`CotizacionVentaEzgoBDT`** apuntando a
  `Reports/Cotización Venta Ezgo.rdl`.
- **Funciones auxiliares**: `GetItemPictureBase64()` y `GetItemPictureMime()`.

### `page 50149 "BDT Buscar App Objeto"` (utilidad)
Archivo: [`Setup/BDTBuscarAppObjeto.Page.al`](Setup/BDTBuscarAppObjeto.Page.al)

Herramienta de diagnóstico: dado un ID de objeto (por defecto `50201`), indica **qué
extensión instalada** lo publica (usa `AllObjWithCaption` → `NAV App Installed App`).
Búscala en el ERP como *"Buscar App de Objeto"*. Puede eliminarse en producción.

### `page 50101 "BDT Importar Img Items"` (carga masiva de imágenes)
Archivo: [`Setup/BDTImportarImgItems.Page.al`](Setup/BDTImportarImgItems.Page.al)

Carga **masiva** de imágenes de productos desde un `.ZIP`. Cada archivo del ZIP debe
llamarse igual que el **N.º del producto** (`1000.jpg`, `ART-005.png`, …). Descomprime en
memoria (`Codeunit "Data Compression"`) y asigna cada imagen al `Item` correspondiente vía
`Item.Picture.ImportStream`. Opción *"Reemplazar imagen existente"*. Al terminar muestra un
resumen (importadas / no encontradas / omitidas). Búscala en el ERP como
*"Importar Imágenes de Productos (ZIP)"*.

> **Nota:** los paquetes de configuración (RapidStart) y "Editar en Excel" **no** cargan
> imágenes; por eso se implementa este importador. Alternativa para integración: la API
> estándar `PATCH .../items({id})/picture`.

---

## Cómo se renderiza la imagen (MediaSet → Base64 → RDL)

`Item.Picture` es de tipo **`MediaSet`** (no un BLOB tradicional). El flujo es:

1. **AL** (por cada línea de tipo *Artículo*):
   `Item.Get(No.)` → `Item.Picture.Count` / `Item.Picture.Item(1)` (GUID del media) →
   `Tenant Media.Get(GUID)` → `CalcFields(Content)` (aquí `Content` **sí** es BLOB) →
   `Base64 Convert.ToBase64(InStream)`.
2. **RDL** (control `<Image>` de la columna "Imagen"):
   - `Source = Database`
   - `Value = =System.Convert.FromBase64String(Fields!ItemPicture_Line.Value)`
   - `MIMEType = =Fields!ItemPictureMime_Line.Value` (dinámico: soporta JPEG/PNG)

Líneas sin artículo o sin foto → celda vacía (sin error).

---

## Compilar y publicar

```text
1. AL: Download Symbols          # trae símbolos de Ezgo Fields + Microsoft
2. Ctrl + Shift + B              # compila (genera el .app)
3. F5                            # publica en el sandbox
```

### Configuración post‑publicación (una sola vez)
En el ERP, en **Selección de informes – Ventas** / **Report Layout Selection**, para el
informe **50201** elige el diseño **"Cotización Venta Ezgo (Bodhitrí)"**
(`CotizacionVentaEzgoBDT`).

Luego imprime una cotización con líneas de **Artículo** que tengan **Imagen** cargada en
la ficha del producto.

---

## Notas técnicas y solución de problemas

| Síntoma | Causa | Solución |
|---|---|---|
| `AL1081: ... File ../Reports/... was not found` | La ruta de `LayoutFile` es **relativa a la raíz del proyecto**, no al `.al`. | Usar `LayoutFile = 'Reports/Cotización Venta Ezgo.rdl';` |
| `El campo Imagen de la tabla Producto debe ser un FlowField` | Se llamó `CalcFields` sobre `Item.Picture` (un **MediaSet**). | No usar `CalcFields` sobre MediaSet; leer con `.Count`/`.Item()`. `CalcFields` solo sobre `Tenant Media.Content` (BLOB). |
| La columna "Imagen" queda a la derecha del todo | Se agregó como última columna del `Tablix` por seguridad al editar el RDL. | Reordenar celdas del tablix si se desea junto a la Descripción. |
| El RDL no cabe en la página | Ancho de página 23 cm; se amplió el *Body* a 22.8 cm y la columna imagen a 1.6 cm. | Ajustar anchos de columnas en el `<TablixColumns>` del RDL. |

### Detalles del layout
- Tabla de líneas: `Tablix5` (dataitem `Line`, tabla `Sales Line`).
- Se añadió una **9ª columna "Imagen"** (encabezado gris + celda con `<Image>`).
- Alto de la fila de detalle: `1.6 cm` (ajustable).

---

## Créditos

Desarrollo: equipo de Tecnología de **Bodhitrí**. Reporte base `50201` provisto por la
extensión *Ezgo Fields* (LyL Consultores).
