// =============================================================================
// Codeunit: BDT Variant Desc. Sync (80803)
// -----------------------------------------------------------------------------
// App ADITIVA que depende de "LyLVariantsExt" (L&L Consultores).
//
// Problema que resuelve:
//   En la línea de la cotización, al cambiar el Código de Variante, la
//   "Descripción de Variante" (Sales Line.LyLDescription) se quedaba con el
//   texto de la variante ANTERIOR.
//
// Por qué pasaba (verificado en el código fuente de BC y de LyL):
//   * El estándar, al validar "Variant Code", solo copia la descripción CORTA
//     de la variante (Item Variant.Description) a Sales Line.Description, vía
//     ItemReferenceMgt.EnterSalesItemReference. No sabe nada de los campos de LyL.
//   * LyL solo rellena LyLDescription en el OnAfterGetRecord del subformulario
//     de la cotización, y únicamente si está VACÍA:
//         if (Rec."Variant Code" <> '') and (Rec.LyLDescription = '') then ...
//     Si la línea ya tenía la descripción de otra variante, no se refresca.
//
// Qué hace:
//   Cada vez que se valida "Variant Code" en una línea de venta de tipo Artículo,
//   copia la descripción larga de la variante elegida (Item Variant."LyL
//   LongDescription") a la línea. Si la variante no tiene descripción larga
//   (por ejemplo, una variante estándar creada a mano), usa su descripción corta.
//   Si se quita la variante, vacía la descripción de variante.
//
// Cuándo se dispara:
//   Siempre que algo VALIDE el código de variante. En la cotización eso es,
//   sobre todo, "Disponibilidad prod. por > Variante" (SalesAvailabilityMgt
//   hace SalesLine.Validate("Variant Code", ...)), pero también copiar
//   documento, sustitución de artículos, etc. El flujo "Acabados" de LyL asigna
//   el código directamente sin Validate y ya rellena LyLDescription él mismo.
//
// Por qué siempre, y no solo cuando la variante cambia:
//   En la cotización LyLDescription es de solo lectura (Editable = false) y LyL
//   siempre la asigna con el mismo texto que guarda en la variante: es un
//   espejo de la variante, no un dato que el usuario personalice. Refrescarla
//   siempre no pisa nada y, además, repara las líneas que ya están desfasadas
//   con solo volver a elegir su variante.
//
// Lo que NO toca:
//   Sales Line.Description lo sigue gestionando el estándar. En el modelo de LyL
//   todas las variantes de un producto se crean con Description = la del
//   artículo, así que esa columna seguirá mostrando el nombre del producto.
// =============================================================================
codeunit 80803 "BDT Variant Desc. Sync"
{
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterValidateEvent', 'Variant Code', false, false)]
    local procedure SyncVariantDescriptionOnAfterValidateVariantCode(var Rec: Record "Sales Line"; var xRec: Record "Sales Line"; CurrFieldNo: Integer)
    begin
        if Rec.Type <> Rec.Type::Item then
            exit;

        Rec.LyLDescription := VariantDescription(Rec."No.", Rec."Variant Code");
    end;

    /// <summary>
    /// Devuelve la descripción que debe mostrar la línea para esa variante:
    /// la larga de LyL si existe; si no, la corta estándar; vacío si no hay
    /// variante o no existe.
    /// </summary>
    local procedure VariantDescription(ItemNo: Code[20]; VariantCode: Code[10]): Text[1000]
    var
        DummySalesLine: Record "Sales Line";
        ItemVariant: Record "Item Variant";
    begin
        if (ItemNo = '') or (VariantCode = '') then
            exit('');

        ItemVariant.SetLoadFields(Description, "LyL LongDescription");
        if not ItemVariant.Get(ItemNo, VariantCode) then
            exit('');

        // LyL LongDescription es Text[2000] y LyLDescription es Text[1000]: se
        // recorta para no provocar un error de desbordamiento en tiempo de
        // ejecución con las descripciones más largas.
        if ItemVariant."LyL LongDescription" <> '' then
            exit(CopyStr(ItemVariant."LyL LongDescription", 1, MaxStrLen(DummySalesLine.LyLDescription)));

        exit(ItemVariant.Description);
    end;
}
