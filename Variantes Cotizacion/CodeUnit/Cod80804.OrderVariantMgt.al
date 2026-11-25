// =============================================================================
// Codeunit: BDT Order Variant Mgt (80804)
// -----------------------------------------------------------------------------
// App ADITIVA que depende de "LyLVariantsExt" (L&L Consultores).
//
// Problema que resuelve:
//   El botón "Acabados" de LyL en el PEDIDO de venta (Pag-Ext 80701, "Sales
//   Order Subform") es la versión SIMPLE: siempre crea el Registro de Variante
//   con VariantCode = '0' y las líneas vacías. Por eso en el pedido el "Código
//   Variante" sale en 0.
//
//   En la COTIZACIÓN, el "Acabados" de LyL (Pag-Ext 80704, "Sales Quote
//   Subform") es la versión COMPLETA: si la variante elegida en la línea ya
//   está registrada (Item Variant nivel 3), pone el código real en el borrador
//   y COPIA sus líneas de detalle ya rellenas.
//
// Qué hace este codeunit:
//   Replica EXACTAMENTE esa lógica completa de la cotización, para usarla desde
//   el subformulario del pedido. Así "Acabados" en el pedido se comporta igual
//   que en la cotización (código correcto + especificaciones copiadas).
//
// No modifica la lógica de LyL: solo crea/lee/actualiza datos en sus tablas
// (LyL ItemVariant, LyL ItemVariantDetails) igual que haría su propio código.
// =============================================================================
codeunit 80804 "BDT Order Variant Mgt"
{
    Permissions = tabledata "LyL ItemVariant" = rimd,
                  tabledata "LyL ItemVariantDetails" = rimd;

    /// <summary>
    /// Abre el Registro de Variante (LyL NewItemVariant) para la línea de venta,
    /// replicando la lógica completa del "Acabados" de la cotización: reutiliza
    /// el borrador si existe, o lo crea tomando el código y las líneas de la
    /// variante registrada elegida en la línea.
    /// </summary>
    procedure OpenVariantDraft(SalesLine: Record "Sales Line")
    var
        Item: Record Item;
        Bom: Record "BOM Component";
        ValidateVariant: Record "LyL ItemVariant";
        NewVariant: Record "LyL ItemVariant";
        ItemVariant: Record "Item Variant";
        VariantCard: Page "LyL NewItemVariant";
        Handled: Boolean;
        IsAssemblyMsg: Label 'El artículo es un ensamble.';
        NoClassMsg: Label 'El artículo no tiene clase de variante asignada.';
    begin
        if SalesLine.Type <> SalesLine.Type::Item then
            exit;
        if not Item.Get(SalesLine."No.") then
            exit;

        Bom.SetRange("Parent Item No.", SalesLine."No.");
        if not Bom.IsEmpty() then begin
            Message(IsAssemblyMsg);
            exit;
        end;

        if Item."LyL VariantClass" = 0 then begin
            Message(NoClassMsg);
            exit;
        end;

        Handled := false;

        if SalesLine."Variant Code" <> '' then begin
            // (1) ¿Ya existe un borrador para esta línea con ese código?
            ValidateVariant.SetRange(VariantCode, SalesLine."Variant Code");
            ValidateVariant.SetRange(ItemId, SalesLine."No.");
            ValidateVariant.SetRange(ClassId, Item."LyL VariantClass");
            ValidateVariant.SetRange(DocumentNo, SalesLine."Document No.");
            ValidateVariant.SetRange(LineNo, SalesLine."Line No.");
            ValidateVariant.SetRange(DocumentType, 'SALES');
            if ValidateVariant.FindFirst() then begin
                Handled := true;
                VariantCard.SetRecord(ValidateVariant);
                VariantCard.Run();
            end else begin
                // (2) Buscar la variante registrada (Item Variant nivel 3).
                ItemVariant.SetRange("Item No.", SalesLine."No.");
                ItemVariant.SetRange(Code, SalesLine."Variant Code");
                ItemVariant.SetRange("LyL Level", 3);
                if ItemVariant.FindFirst() then
                    Handled := PrepareFromRegisteredVariant(SalesLine, Item, ItemVariant, VariantCard);
            end;
        end;

        // (3) Nada emparejó: crear un borrador de validación vacío (como LyL).
        if not Handled then begin
            NewVariant.Init();
            NewVariant.ClassId := Item."LyL VariantClass";
            NewVariant.ItemId := SalesLine."No.";
            NewVariant.VariantCode := '0';
            NewVariant.VariantDescription := 'VALIDATION';
            NewVariant.LineNo := SalesLine."Line No.";
            NewVariant.DocumentNo := SalesLine."Document No.";
            NewVariant.DocumentType := 'SALES';
            NewVariant.Insert();
            VariantCard.SetRecord(NewVariant);
            VariantCard.Run();
        end;
    end;

    /// <summary>
    /// Prepara el borrador a partir de una variante ya registrada: enlaza el
    /// borrador existente de esta línea (poniéndole el código real) o crea uno
    /// nuevo copiando las líneas de detalle de la variante registrada.
    /// Devuelve true si abrió la ficha.
    /// </summary>
    local procedure PrepareFromRegisteredVariant(SalesLine: Record "Sales Line"; Item: Record Item; ItemVariant: Record "Item Variant"; var VariantCard: Page "LyL NewItemVariant"): Boolean
    var
        ValidateVariant: Record "LyL ItemVariant";
        NewVariant: Record "LyL ItemVariant";
        SourceDetails: Record "LyL ItemVariantDetails";
        NewData: Record "LyL ItemVariantDetails";
    begin
        // (2a) ¿Hay un borrador de esta línea ligado a la variante registrada?
        ValidateVariant.SetRange(ItemId, SalesLine."No.");
        ValidateVariant.SetRange(LineNo, SalesLine."Line No.");
        ValidateVariant.SetRange(ClassId, Item."LyL VariantClass");
        ValidateVariant.SetRange(DocumentNo, SalesLine."Document No.");
        ValidateVariant.SetRange(DocumentType, 'SALES');
        ValidateVariant.SetRange(ID, ItemVariant."LyL IdVariant");
        if ValidateVariant.FindFirst() then begin
            ValidateVariant.consecutive := ItemVariant."LyL Consecutive";
            ValidateVariant.VariantCode := ItemVariant.Code;
            ValidateVariant.Modify();
            Commit();
            VariantCard.SetRecord(ValidateVariant);
            VariantCard.Run();
            exit(true);
        end;

        // (2b) Usar la variante registrada como plantilla: crear borrador nuevo
        //      copiando su código y sus líneas de detalle ya rellenas.
        Clear(ValidateVariant);
        ValidateVariant.SetRange(ItemId, SalesLine."No.");
        ValidateVariant.SetRange(ID, ItemVariant."LyL IdVariant");
        if not ValidateVariant.FindFirst() then
            exit(false);

        NewVariant.Init();
        NewVariant.ClassId := Item."LyL VariantClass";
        NewVariant.ItemId := SalesLine."No.";
        NewVariant.VariantCode := SalesLine."Variant Code";
        NewVariant.VariantDescription := 'VALIDATION';
        NewVariant.LineNo := SalesLine."Line No.";
        NewVariant.DocumentNo := SalesLine."Document No.";
        NewVariant.DocumentType := 'SALES';
        NewVariant.variantGenCode := ValidateVariant.variantGenCode;
        NewVariant.Insert();

        SourceDetails.SetRange(VariantId, ItemVariant."LyL IdVariant");
        if SourceDetails.FindSet() then
            repeat
                NewData.Init();
                NewData.SpecID := SourceDetails.SpecID;
                NewData.SpecDescription := SourceDetails.SpecDescription;
                NewData.FeatureDescription := SourceDetails.FeatureDescription;
                NewData.FeatureID := SourceDetails.FeatureID;
                NewData.FeatureDetailDescription := SourceDetails.FeatureDetailDescription;
                NewData.FeatureDetailID := SourceDetails.FeatureDetailID;
                NewData.FeatureCode := SourceDetails.FeatureCode;
                NewData.IdClass := NewVariant.ClassId;
                NewData.ItemID := NewVariant.ItemId;
                NewData.VariantId := NewVariant.ID;
                NewData.Level4ID := SourceDetails.Level4ID;
                NewData.Level5 := SourceDetails.Level5;
                NewData.MonedaLP := SourceDetails.MonedaLP;
                NewData.NewFeatureDetailID := SourceDetails.NewFeatureDetailID;
                NewData.PriceLP := SourceDetails.PriceLP;
                NewData.Insert();
            until SourceDetails.Next() = 0;

        VariantCard.SetRecord(NewVariant);
        VariantCard.Run();
        exit(true);
    end;
}
