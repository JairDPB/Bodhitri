// =============================================================================
// Codeunit: BDT Variant Detail Builder
// -----------------------------------------------------------------------------
// App ADITIVA que depende de "LyLVariantsExt" (L&L Consultores).
//
// Función: RELLENAR el Acabado y el Tipo de Acabado de las líneas ya existentes
// de una variante (tabla LyL ItemVariantDetails 80705, vistas en el ListPart
// 80707), descomponiendo la "Descripción de Variante" de la variante de
// REFERENCIA elegida en la línea de la cotización.
//
// ¿De dónde sale la descripción? (relación descubierta en el código de LyL)
//   El botón "Acabados" de LyL crea el "Registro de Variante" (LyL ItemVariant
//   80706) guardando el documento de venta origen: DocumentNo + LineNo
//   (DocumentType='SALES'). La línea de venta tiene el "Variant Code" elegido,
//   cuya Item Variant (5401) contiene la "LyL LongDescription" (campo 80703).
//   Cadena:  borrador 80706 -> Sales Line (DocumentNo+LineNo) -> Variant Code
//            -> Item Variant -> LyL LongDescription.
//
// IMPORTANTE: las líneas (una por Especificación) las crea LyL con SpecID/
// SpecDescription puestos y Feature/FeatureDetail vacíos. Este proceso NO crea
// ni borra líneas: solo COMPLETA las existentes y dispara el recálculo propio
// de LyL (evento OnAfterModify del codeunit 80700).
//
// Formato del texto:  "<Espec>: <Acabado> <TipoAcabado>  ; <Espec>: ... ; ..."
// =============================================================================
codeunit 80801 "BDT Variant Detail Builder"
{
    Permissions = tabledata "LyL ItemVariantDetails" = rimd;

    /// <summary>
    /// Rellena el Acabado/Tipo de Acabado de las líneas existentes de la variante
    /// a partir de la descripción de la variante de referencia (línea de venta).
    /// </summary>
    procedure FillDetailsFromDescription(var LyLVariant: Record "LyL ItemVariant")
    var
        Detail: Record "LyL ItemVariantDetails";
        SpecToRest: Dictionary of [Text, Text];
        LongDesc: Text;
        SpecKey: Text;
        Filled: Integer;
        Unmatched: Integer;
        NoSourceErr: Label 'No se encontró descripción de referencia.\Origen del borrador: Documento ''%1'', Línea %2.\Verifique que esa línea de venta tenga un Código de Variante seleccionado (de ahí se toma la "Descripción de Variante").', Comment = '%1=DocumentNo, %2=LineNo';
        NoLinesMsg: Label 'Esta variante no tiene líneas de especificación que rellenar.';
        OkMsg: Label 'Se rellenaron %1 línea(s) de especificación desde la descripción.', Comment = '%1=cantidad';
        PartialMsg: Label 'Se rellenaron %1 línea(s). %2 línea(s) no se pudieron emparejar (la especificación no está en la descripción, o el Acabado/Tipo no existe en las maestras).', Comment = '%1=rellenadas, %2=sin emparejar';
    begin
        // 1. Obtener la descripción de la variante de referencia.
        if not GetSourceLongDescription(LyLVariant, LongDesc) then
            Error(NoSourceErr, LyLVariant.DocumentNo, LyLVariant.LineNo);

        // 2. Descomponer el texto en  Especificación -> "Acabado TipoAcabado".
        ParseDescription(LongDesc, SpecToRest);

        // 3. Recorrer las líneas EXISTENTES de la variante y completar sus acabados.
        Detail.SetRange(VariantId, LyLVariant.ID);
        if not Detail.FindSet(true) then begin
            Message(NoLinesMsg);
            exit;
        end;
        repeat
            SpecKey := UpperCase(Detail.SpecDescription);
            SpecKey := SpecKey.Trim();
            if SpecToRest.ContainsKey(SpecKey) then begin
                if FillFeatureOnDetail(Detail, SpecToRest.Get(SpecKey)) then
                    Filled += 1
                else
                    Unmatched += 1;
            end else
                Unmatched += 1;
        until Detail.Next() = 0;

        // 4. Informar el resultado.
        if Unmatched = 0 then
            Message(OkMsg, Filled)
        else
            Message(PartialMsg, Filled, Unmatched);
    end;

    /// <summary>
    /// Obtiene la "LyL LongDescription" de referencia para el borrador:
    ///  (A) vía la línea de venta origen (DocumentNo+LineNo) -> Variant Code -> Item Variant;
    ///  (B) fallback: si el borrador ya está ligado a una Item Variant registrada.
    /// Devuelve false si no encuentra ninguna descripción.
    /// </summary>
    local procedure GetSourceLongDescription(LyLVariant: Record "LyL ItemVariant"; var LongDesc: Text): Boolean
    var
        SalesLine: Record "Sales Line";
        ItemVariant: Record "Item Variant";
    begin
        // (A) Por el documento de venta que originó el borrador.
        if FindSalesLine(LyLVariant, SalesLine) then begin
            if SalesLine."Variant Code" <> '' then
                if ItemVariant.Get(SalesLine."No.", SalesLine."Variant Code") then
                    if ItemVariant."LyL LongDescription" <> '' then begin
                        LongDesc := ItemVariant."LyL LongDescription";
                        exit(true);
                    end;
            // La propia línea ya suele tener copiada la descripción (Text[1000]).
            if SalesLine.LyLDescription <> '' then begin
                LongDesc := SalesLine.LyLDescription;
                exit(true);
            end;
        end;

        // (B) Fallback: el borrador ya ligado a una Item Variant registrada.
        ItemVariant.Reset();
        ItemVariant.SetRange("LyL IdVariant", LyLVariant.ID);
        if ItemVariant.FindFirst() then
            if ItemVariant."LyL LongDescription" <> '' then begin
                LongDesc := ItemVariant."LyL LongDescription";
                exit(true);
            end;

        if LyLVariant.variantGenCode <> '' then begin
            ItemVariant.Reset();
            ItemVariant.SetRange("Item No.", LyLVariant.ItemId);
            ItemVariant.SetRange("LyL VariantGenCode", LyLVariant.variantGenCode);
            if ItemVariant.FindFirst() then
                if ItemVariant."LyL LongDescription" <> '' then begin
                    LongDesc := ItemVariant."LyL LongDescription";
                    exit(true);
                end;
        end;

        exit(false);
    end;

    /// <summary>
    /// Localiza la línea de venta (Cotización u Orden) que originó el borrador,
    /// usando DocumentNo + LineNo guardados en el registro LyL ItemVariant.
    /// </summary>
    local procedure FindSalesLine(LyLVariant: Record "LyL ItemVariant"; var SalesLine: Record "Sales Line"): Boolean
    begin
        if (LyLVariant.DocumentNo = '') or (LyLVariant.DocumentNo = '0') then
            exit(false);

        SalesLine.SetRange("Document No.", LyLVariant.DocumentNo);
        SalesLine.SetRange("Line No.", LyLVariant.LineNo);

        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Quote);
        if SalesLine.FindFirst() then
            exit(true);

        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        if SalesLine.FindFirst() then
            exit(true);

        exit(false);
    end;

    /// <summary>
    /// Descompone la LongDescription en pares Especificación -> "Acabado TipoAcabado".
    /// La clave se normaliza en mayúsculas y sin espacios extremos.
    /// </summary>
    local procedure ParseDescription(LongDesc: Text; var SpecToRest: Dictionary of [Text, Text])
    var
        Segments: List of [Text];
        Segment: Text;
        SpecName: Text;
        Rest: Text;
        ColonPos: Integer;
    begin
        Clear(SpecToRest);
        Segments := LongDesc.Split(';');
        foreach Segment in Segments do begin
            Segment := Segment.Trim();
            if Segment <> '' then begin
                ColonPos := Segment.IndexOf(':');
                if ColonPos > 0 then begin
                    SpecName := Segment.Substring(1, ColonPos - 1);
                    SpecName := UpperCase(SpecName);
                    SpecName := SpecName.Trim();
                    Rest := Segment.Substring(ColonPos + 1);
                    Rest := Rest.Trim();
                    if (SpecName <> '') and (Rest <> '') and (not SpecToRest.ContainsKey(SpecName)) then
                        SpecToRest.Add(SpecName, Rest);
                end;
            end;
        end;
    end;

    /// <summary>
    /// Empareja "Acabado TipoAcabado" con las maestras (usando el SpecID de la
    /// línea) y completa los campos de la línea. Devuelve false si no empareja.
    /// </summary>
    local procedure FillFeatureOnDetail(var Detail: Record "LyL ItemVariantDetails"; Rest: Text): Boolean
    var
        Feature: Record "LyL SpecsFeatures";
        FeatureDetail: Record "LyL SpecsFeaturesDetalis";
        Matched: Boolean;
    begin
        Feature.SetRange(IdSpec, Detail.SpecID);
        if Feature.FindSet() then
            repeat
                if Rest.StartsWith(Feature.Description + ' ') then begin
                    FeatureDetail.Reset();
                    FeatureDetail.SetRange(FeatureId, Feature.ID);
                    FeatureDetail.SetRange(Description, Rest.Substring(StrLen(Feature.Description) + 1).Trim());
                    if FeatureDetail.FindFirst() then begin
                        Matched := true;
                        Detail.FeatureID := Feature.ID;
                        Detail.FeatureDescription := Feature.Description;
                        Detail.FeatureDetailID := FeatureDetail.ID;
                        Detail.FeatureDetailDescription := FeatureDetail.Description;
                        Detail.FeatureCode := FeatureDetail."Code";
                    end;
                end;
            until (Feature.Next() = 0) or Matched;

        if not Matched then
            exit(false);

        // Al modificar, LyL (codeunit 80700) recalcula variantGenCode / Costo FOB.
        Detail.Modify(true);
        exit(true);
    end;
}
