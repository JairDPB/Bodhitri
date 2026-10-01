# Rellenado de Acabados de Variante desde la Descripción (Business Central)

## 📋 Descripción General

Extensión en **AL** que, desde la ficha **"Registro de Variante" (`LyL NewItemVariant`, 80708)**, **rellena el Acabado y el Tipo de Acabado** de las líneas de especificación de una variante — tabla **`LyL ItemVariantDetails` (80705)**, vista en el ListPart **`LyL NewItemVariantListPart` (80707)** — **descomponiendo la "Descripción de Variante"** almacenada en `Item Variant."LyL LongDescription"` (campo 80703, Text[2000]).

> **App aditiva, dependiente de `LyLVariantsExt` (L&L Consultores).** No modifica la lógica de LyL ni de tablas estándar. **No crea ni borra líneas**: solo **completa las existentes** (las que crea el flujo "Acabados" de LyL) y dispara el recálculo propio de LyL (evento `OnAfterModify` del codeunit 80700).

---

## 🎯 Qué hace

Las líneas de la variante ya existen (una por **Especificación**: ESPALDAR, ASIENTO, ESTRUCTURA…) con el Acabado y el Tipo de Acabado **vacíos**. Dada la descripción almacenada:

```
ESPALDAR NA: MALLA NA NEGRA  ; ASIENTO NA: TAPIZADO NA G2 ; ESTRUCTURA NA: PLASTICO NA NYLON  ; ...
```

…la acción la **descompone** y, para cada línea existente, **completa** el Acabado y el Tipo de Acabado (y sus IDs/`FeatureCode`) emparejando contra las tablas maestras de LyL.

---

## 🧱 Modelo de datos (de LyLVariantsExt)

| Objeto | Rol |
|--------|-----|
| `Item Variant` (5401) · campo `LyL LongDescription` (80703, Text[2000]) | **Fuente**: la "Descripción de Variante" (texto concatenado) |
| `LyL ItemVariant` (80706) | Cabecera de variante (`SourceTable` de la ficha 80708) |
| **`LyL ItemVariantDetails` (80705)** | **Destino**: líneas a completar (`SpecDescription` ya viene; se rellena `FeatureDescription`, `FeatureDetailDescription` + IDs/`FeatureCode`) |
| `LyL VariantsSpecs` (80700) | Maestra de **Especificaciones** (ESPALDAR NA) |
| `LyL SpecsFeatures` (80702) | Maestra de **Acabados** (MALLA NA) |
| `LyL SpecsFeaturesDetalis` (80703) | Maestra de **Tipos de Acabado** (NEGRA / G2 / NYLON) + su `Code` |

---

## 📁 Objetos de esta extensión

```
Variantes Cotizacion/
├── app.json                                       (Dependencia → LyLVariantsExt)
├── CodeUnit/
│   ├── Cod80801.VariantDetailBuilder.al           (Lógica: parseo + emparejamiento + relleno)
│   └── Cod80803.VariantDescSync.al                (Refresca la Descripción de Variante en la línea)
└── pages/
    └── PagExt80802.LyLNewItemVariantExt.al        (Acción en la ficha 80708)
```

| Objeto | ID | Tipo | Rol |
|--------|----|----|-----|
| `BDT Variant Detail Builder` | 80801 | Codeunit | Descompone la descripción y rellena las líneas existentes |
| `BDT LyL NewItemVariant Ext` | 80802 | PageExtension | Acción **"Generar detalles desde descripción"** en la ficha 80708 |
| `BDT Variant Desc. Sync` | 80803 | Codeunit | Al cambiar la variante de una línea de venta, actualiza su **Descripción de Variante** |

**Dependencia** (`app.json`): `LyLVariantsExt` · `82b819df-9a08-4cba-a31b-e08ef2612729` · L&L Consultores · v `1.0.0.0` (mín.).

---

## ⚙️ Cómo funciona (paso a paso)

1. El usuario abre una variante en **"Registro de Variante"** (80708) y pulsa **"Generar detalles desde descripción"** (con confirmación).
2. El codeunit obtiene la **descripción de referencia**: el borrador (LyL ItemVariant) guarda `DocumentNo` + `LineNo` de la línea de venta que lo originó (botón "Acabados"). Localiza esa **Sales Line**, lee su **`Variant Code`** y de la **Item Variant** (5401) correspondiente toma `LyL LongDescription`. *(Fallbacks: `SalesLine.LyLDescription`, o el `LyL IdVariant` / `VariantGenCode` del borrador.)*
3. **Descompone** el texto en pares `Especificación → "Acabado TipoAcabado"`:
   - Separa por `;` → cada segmento es una especificación.
   - Separa cada segmento por `:` → `Especificación` y `Acabado TipoAcabado`.
4. **Recorre las líneas existentes** de la variante (`LyL ItemVariantDetails`, por `VariantId`). Para cada línea busca su `Especificación` en el texto y, si la encuentra, **empareja** usando el `SpecID` de la línea:
   - `Acabado` → `LyL SpecsFeatures` (`IdSpec` = SpecID de la línea), como **prefijo** del texto (el acabado puede ser multi-palabra: "MALLA NA").
   - `TipoAcabado` (el resto) → `LyL SpecsFeaturesDetalis` → de ahí el `FeatureCode`.
5. **Completa** en la línea: `FeatureID`, `FeatureDescription`, `FeatureDetailID`, `FeatureDetailDescription`, `FeatureCode`, y la guarda. Al modificarla, LyL (codeunit 80700) recalcula `variantGenCode` / `Costo FOB`.
6. Muestra cuántas líneas se rellenaron y cuántas no se pudieron emparejar.

---

## 🔄 Descripción de Variante sincronizada con la línea

**Problema:** en la cotización, al cambiar el Código de Variante de una línea (por ejemplo
desde **Disponibilidad prod. por → Variante**), la columna **"Descripción de Variante"**
se quedaba con el texto de la variante anterior.

**Causa** (verificada en el código fuente de BC 27.5 y de LyL):

- El estándar, al validar `Variant Code`, solo copia la descripción **corta** de la variante
  (`Item Variant.Description`) a `Sales Line.Description`. No conoce los campos de LyL.
- LyL solo rellena `Sales Line.LyLDescription` en el `OnAfterGetRecord` del subformulario
  de la cotización, y **solo si está vacía**. Si ya tenía la de otra variante, no la cambia.

**Solución:** `BDT Variant Desc. Sync` (80803) se suscribe al `OnAfterValidateEvent` de
`Sales Line."Variant Code"`. Cada vez que se valida la variante en una línea de tipo
Artículo, copia `Item Variant."LyL LongDescription"` a `LyLDescription` (recortada a 1.000
caracteres; si la variante no tiene descripción larga, usa la corta). Si se quita la
variante, la vacía.

> **La columna "Descripción" no cambia, y es lo esperado.** LyL crea todas las variantes de
> un producto con `Description` = la del artículo, así que esa columna sigue mostrando el
> nombre del producto. Lo que distingue a cada variante es la **Descripción de Variante**.

**Líneas que ya están desfasadas:** se corrigen volviendo a elegir su variante desde
*Disponibilidad prod. por → Variante*. Se refresca siempre, aunque sea la misma variante.

---

## 🚀 Uso

1. **AL: Download Symbols** (la dependencia ya está en `app.json`).
2. Compilar (`Ctrl + Shift + B`) y publicar (`F5`).
3. Abrir **Registro de Variante** y pulsar **"Generar detalles desde descripción"**.

> ✅ Compila limpio (verificado con `alc.exe` 17.0, 0 errores / 0 warnings, contra los símbolos reales de `LyLVariantsExt`).

---

## ⚠️ Consideraciones / Límites

- **Solo rellena líneas que ya existen** (creadas por el flujo "Acabados" de LyL). No crea ni borra líneas.
- **Origen de la descripción:** la variante de referencia es la del **`Variant Code` de la línea de venta** que originó el borrador (vínculo `DocumentNo`+`LineNo`). **Requisito:** esa línea debe tener un Código de Variante seleccionado. Si en tu flujo la referencia se elige de otra forma, se ajusta `GetSourceLongDescription` (p. ej. añadir un selector de variante).
- **El emparejamiento exige las maestras** (Acabado/TipoAcabado). Si una línea no empareja, se deja sin tocar y se reporta (no rompe el proceso).
- Procesa el formato **base (Nivel 3)**: `Especificación: Acabado TipoAcabado`. Niveles 4/5 (Detalle/Categoría) no se descomponen.
- El **precio** no sale del texto; el `Costo FOB` lo recalcula LyL.

---

## 📞 Notas
- **Autor**: Equipo de Desarrollo — Bodhitri
- **Versión**: 2.2.0 (Descripción de Variante sincronizada al cambiar la variante de la línea)
- **Última Actualización**: 2026-10-01

> Versiones previas (autocomplete de `Variant Code` en la Cotización, o borrado+recreación de líneas) eran enfoques incorrectos y fueron reemplazados por este.
