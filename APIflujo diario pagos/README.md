# API — Flujo diario de pagos (Gen. Journal Line)

API personalizada de Business Central que expone la tabla **Gen. Journal Line (81)**
como entidad OData v4, para que un flujo de **Power Automate** cree líneas de
"Diarios de pagos" a partir de los valores de una **lista de SharePoint**.

> **Patrón:** 1 fila de SharePoint → 1 POST → 1 línea de diario (sin registrar).
> El registro/posting del diario se hace dentro de BC (queda fuera de esta API).

- **Objeto:** `page 50100 "BDT Gen. Journal Line API"` → [Pag50100.GenJournalLineAPI.al](pages/Pag50100.GenJournalLineAPI.al)
- **Tabla origen:** `Gen. Journal Line` (81)
- **Clave OData:** `SystemId` (estable; no requiere conocer el `N.º línea`)

> ### Nota sobre los nombres en español
> En una API **personalizada**, lo que Power Automate muestra como nombre de
> cada campo es el **nombre de la propiedad JSON** (= nombre del control en AL),
> **no** el `Caption`. La API estándar de BC se ve en español porque el conector
> de Microsoft está localizado. Por eso aquí los campos se llaman en español
> (camelCase, sin acentos), p. ej. `fechaRegistro`, `numeroCuenta`,
> `tipoMovimiento`; y el `Caption` además lleva el texto exacto de BC.

---

## 1. Endpoint

```
https://api.businesscentral.dynamics.com/v2.0/{tenantId}/{environment}/api/bodhitri/pagos/v1.0/companies({companyId})/genJournalLines
```

| Parte          | Valor              |
|----------------|--------------------|
| `apiPublisher` | `bodhitri`         |
| `apiGroup`     | `pagos`            |
| `apiVersion`   | `v1.0`             |
| EntitySet      | `genJournalLines`  |

Para obtener `{companyId}`:
`.../api/bodhitri/pagos/v1.0/companies` → toma el `id` (GUID) de tu empresa.

---

## 2. Mapeo de campos — propiedad API ⇄ Tabla 81 ⇄ columna SharePoint

| Propiedad API (JSON)          | Caption / columna en BC        | Campo tabla "Gen. Journal Line" | Tipo      | Columna SharePoint | Notas |
|-------------------------------|--------------------------------|---------------------------------|-----------|--------------------|-------|
| `nombrePlantilla`             | Nombre plantilla               | Journal Template Name           | Code[10]  | Plantilla          | **Requerido**. Plantilla del diario. |
| `nombreSeccion`               | Nombre sección                 | Journal Batch Name              | Code[10]  | Seccion            | **Requerido**. P. ej. `TESORERIA`. |
| `numeroLinea`                 | N.º línea                      | Line No.                        | Integer   | — (no enviar)      | Solo lectura. Lo asigna el servidor. |
| `fechaRegistro`               | Fecha registro                 | Posting Date                    | Date      | FechaExtracto      | Si va vacío usa la fecha de trabajo. |
| `fechaDocumento`              | Fecha documento                | Document Date                   | Date      |                    | |
| `tipoDocumento`               | Tipo documento                 | Document Type                   | Enum      |                    | Pagos: `Payment`. Ver valores abajo. |
| `numeroDocumento`             | N.º documento                  | Document No.                    | Code[20]  |                    | |
| `numeroDocumentoExterno`      | N.º documento externo          | External Document No.           | Code[35]  |                    | |
| `tipoMovimiento`              | Tipo mov.                      | Account Type                    | Enum      | (constante)        | Pago a proveedor: `Vendor`. Ver valores. |
| `numeroCuenta`                | N.º cuenta                     | Account No.                     | Code[20]  | ReferenciaNit      | N.º del proveedor/cliente/cuenta. |
| `descripcion`                 | Descripción                    | Description                     | Text[100] | ReferenciaPago     | |
| `codigoDivisa`                | Cód. divisa                    | Currency Code                   | Code[10]  |                    | Vacío = moneda local. |
| `importe`                     | Importe                        | Amount                          | Decimal   | Monto              | Signo según contabilidad (ver §5). |
| `importeMonedaLocal`          | Importe ($)                    | Amount (LCY)                    | Decimal   | — (no enviar)      | Solo lectura (lo calcula BC). |
| `tipoContrapartida`           | Tipo contrapartida             | Bal. Account Type               | Enum      | (constante)        | Banco: `Bank Account`. |
| `cuentaContrapartida`         | Cta. contrapartida             | Bal. Account No.                | Code[20]  |                    | N.º de banco/cuenta (p. ej. `001`). |
| `liquidarPorTipoDocumento`    | Liq. por tipo documento        | Applies-to Doc. Type            | Enum      |                    | Saldar factura: `Invoice`. |
| `liquidarPorNumeroDocumento`  | Liq. por n.º documento         | Applies-to Doc. No.             | Code[20]  |                    | N.º de la factura a saldar. |
| `idLiquidacion`               | Liq. por Id.                   | Applies-to ID                   | Code[50]  |                    | Alternativa a Tipo/N.º. |
| `fechaVencimiento`            | Fecha vencimiento              | Due Date                        | Date      |                    | |
| `codigoFormaPago`             | Cód. forma pago                | Payment Method Code             | Code[10]  |                    | |
| `referenciaPago`              | Referencia pago                | Payment Reference               | Code[50]  |                    | |
| `numeroAcreedor`              | N.º acreedor                   | Creditor No.                    | Code[20]  |                    | |
| `tipoPagoPorBanco`            | Tipo pago por banco            | Bank Payment Type               | Enum      |                    | P. ej. `Manual Check`. Ver valores. |
| `cuentaBancariaDestinatario`  | Cta. bancaria destinatario     | Recipient Bank Account          | Code[20]  |                    | |
| `mensajeAlDestinatario`       | Mensaje al destinatario        | Message to Recipient            | Text[140] |                    | |
| `grupoContableIVANegocio`     | Grupo contable IVA negocio     | VAT Bus. Posting Group          | Code[20]  |                    | |
| `comentario`                  | Comentario                     | Comment                         | Text[80]  | Descripción        | |
| `codigoDimension1`            | Cód. dimensión 1               | Shortcut Dimension 1 Code       | Code[20]  |                    | Opcional. |
| `codigoDimension2`            | Cód. dimensión 2               | Shortcut Dimension 2 Code       | Code[20]  |                    | Opcional. |
| `id`                          | Id                             | SystemId                        | GUID      | — (no enviar)      | Clave. Devuelta al crear. |
| `lastModifiedDateTime`        | Última modificación            | SystemModifiedAt                | DateTime  | — (no enviar)      | Solo lectura. |

### Valores de los Enum (enviar el texto exacto)

- **`tipoDocumento` / `liquidarPorTipoDocumento`** (`Gen. Journal Document Type`):
  `" "` (vacío), `Payment`, `Invoice`, `Credit Memo`, `Finance Charge Memo`, `Reminder`, `Refund`
- **`tipoMovimiento` / `tipoContrapartida`** (`Gen. Journal Account Type`):
  `G/L Account`, `Customer`, `Vendor`, `Bank Account`, `Fixed Asset`, `IC Partner`, `Employee`, `Allocation Account`
- **`tipoPagoPorBanco`** (`Bank Payment Type`):
  `" "` (vacío), `Computer Check`, `Manual Check`, `Electronic Payment`, `Electronic Payment-IAT`

---

## 3. Ejemplo de cuerpo (POST) — pago a proveedor saldando una factura

```http
POST .../companies({companyId})/genJournalLines
Content-Type: application/json
```
```json
{
  "nombrePlantilla": "PAGOS",
  "nombreSeccion": "TESORERIA",
  "fechaRegistro": "2026-05-06",
  "tipoDocumento": "Payment",
  "numeroDocumento": "PAG-000123",
  "tipoMovimiento": "Vendor",
  "numeroCuenta": "901710024",
  "descripcion": "Pago NUEVA VANSOLIX S.A.",
  "importe": -207421.30,
  "tipoContrapartida": "Bank Account",
  "cuentaContrapartida": "001",
  "liquidarPorTipoDocumento": "Invoice",
  "liquidarPorNumeroDocumento": "FAC-0098",
  "tipoPagoPorBanco": "Manual Check"
}
```

La respuesta incluye `id` (SystemId) y `numeroLinea` ya asignados.

---

## 4. Flujo en Power Automate (paso a paso)

1. **Disparador:** *When an item is created/modified* (SharePoint) o *Recurrence* + *Get items*.
2. **(Recomendado) Filtra** las filas pendientes con una columna de estado, p. ej. `Estado eq 'Pendiente'`.
3. **Apply to each** sobre los `value` de *Get items*.
4. Dentro del bucle, acción del conector **Business Central** → **"Create record (V3)"**:
   - API category `bodhitri`, tabla `genJournalLines`.
   - Mapea cada columna de SharePoint a su propiedad según §2
     (los campos ahora aparecen en español: `nombreSeccion`, `numeroCuenta`,
     `fechaRegistro`, `importe`, `descripcion`…).
   - Para `tipoMovimiento` y `tipoContrapartida` usa valores constantes
     (`Vendor`, `Bank Account`).
   - **Alternativa:** acción **HTTP** (POST al endpoint del §1) con OAuth 2.0.
5. **(Recomendado)** Tras crear, **Update item** en SharePoint marcando `Estado = 'Creado'`
   y guardando el `id`/`numeroLinea` devueltos (idempotencia y trazabilidad).
6. **Control de errores:** configura *Run after* (has failed) para marcar `Estado = 'Error'`
   y registrar el mensaje, así una fila mala no detiene el lote.

> **Idempotencia:** procesa solo filas en estado `Pendiente`, o usa
> `numeroDocumento` como referencia única antes de crear, para evitar duplicados.

---

## 5. Notas importantes

- **Signo del importe (`importe`):** en un pago a proveedor con contrapartida banco,
  la línea del proveedor suele ir **negativa** (como en tu captura: `-207.421,30`).
  El signo depende de tu configuración contable; valida con un caso real antes de
  operar en producción.
- **Validaciones:** la API ejecuta las mismas validaciones de campo que la ficha del
  diario (resuelve proveedor/banco, fechas, liquidación a documentos…). Envía los
  campos en el orden de §2 (de arriba a abajo) para que las dependencias se resuelvan
  bien (p. ej. `tipoMovimiento` **antes** que `numeroCuenta`).
- **Permisos:** la credencial que usa Power Automate necesita el conjunto de permisos
  **"BDT Pagos API"** ([Per50100.PagosAPI.al](permissions/Per50100.PagosAPI.al)) o uno
  que otorgue `tabledata 81 = RIMD` y ejecución de la página 50100.
- **Registro (posting):** esta API **no registra** el diario. El registro se hace en BC.
- **Nombres de la API** (`bodhitri` / `pagos` / `v1.0`) y de la entidad se pueden cambiar
  en las propiedades de [Pag50100.GenJournalLineAPI.al](pages/Pag50100.GenJournalLineAPI.al);
  si los cambias, actualiza la URL del §1.

---

## 6. Publicar / actualizar la extensión

- **Compilar:** `Ctrl+Shift+B` en VS Code (o `AL: Package`).
- **Publicar:** `F5` (publish + debug) o `Ctrl+F5` (publish sin debug) contra el sandbox
  de [.vscode/launch.json](.vscode/launch.json).
- Rango de IDs del proyecto: **50100–50149** (`app.json`). Página y permission set usan **50100**.
- Tras publicar, **refresca la conexión de Business Central en Power Automate** para que
  aparezca la API `bodhitri/pagos` y la tabla `genJournalLines` con los campos en español.
