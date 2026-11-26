// =============================================================================
// Codeunit: BDT Order Variant Mgt (80804)
// -----------------------------------------------------------------------------
// App ADITIVA que depende de "LyLVariantsExt" (L&L Consultores).
//
// Problema que resuelve:
//   En el PEDIDO de venta, al pulsar "Acabados" en una línea con variante, el
//   "Registro de Variante" se abría con Código Variante = '0', especificaciones
//   vacías y Costo FOB 0, en lugar de mostrar la variante que usa la línea
//   (como sí ocurre en la COTIZACIÓN).
//
// Por qué pasaba (verificado en el código fuente de LyL):
//   * El "Acabados" de LyL en el pedido (Pag-Ext 80701, "Sales Order Subform")
//     solo busca un borrador (LyL ItemVariant) de ESA línea con el código de la
//     línea. Si no lo encuentra, crea siempre uno nuevo con VariantCode = '0'.
//   * El de la cotización (Pag-Ext 80704) además toma la variante registrada de
//     la línea y copia su código y sus especificaciones, pero SOLO si la
//     variante es de NIVEL 3. En el pedido las variantes suelen ser de NIVEL 4
//     (las crea LyL al registrar desde un pedido) o variantes elegidas a mano en
//     el campo "Cód. variante" (en el pedido es editable). Por eso copiar la
//     lógica de la cotización tal cual seguía mostrando '0'.
//
// Qué hace (misma lógica que la cotización, sin limitarse al nivel 3):
//   (1) Si ya existe un borrador de esta línea con el código de la línea, lo abre.
//   (2) Si no, toma la Item Variant de la línea y el borrador que la registró
//       (campo "LyL IdVariant"):
//       (2a) si ese borrador es de esta misma línea, le pone el código y lo abre;
//       (2b) si es de otro documento (p. ej. la cotización de origen), crea un
//            borrador para esta línea con el código de la variante y copia su
//            variantGenCode, Costo FOB y especificaciones ya rellenas.
//       (2c) Si la variante no tiene registro de LyL (creada a mano), crea el
//            borrador con el código de la línea; las especificaciones vacías de
//            la clase las genera la propia ficha de LyL al abrirse.
//   (3) Si la línea no tiene variante, crea el borrador con código '0' (igual
//       que LyL), listo para elegir los acabados y "Registrar".
//
// No modifica la lógica de LyL: solo crea/lee/actualiza datos en sus tablas
// (LyL ItemVariant, LyL ItemVariantDetails) igual que haría su propio código.
// =============================================================================
codeunit 80804 "BDT Order Variant Mgt"
{
    Permissions = tabledata "LyL ItemVariant" = rimd,
                  tabledata "LyL ItemVariantDetails" = rimd;

    var
        SalesDocTypeTok: Label 'SALES', Locked = true;
        ValidationTok: Label 'VALIDATION', Locked = true;
        NoVariantTok: Label '0', Locked = true;

    /// <summary>
    /// Abre el Registro de Variante (LyL NewItemVariant) de la línea de venta
    /// mostrando la variante que usa la línea: su código y sus especificaciones.
    /// </summary>
    procedure OpenVariantDraft(SalesLine: Record "Sales Line")
    var
        Item: Record Item;
        Draft: Record "LyL ItemVariant";
        VariantCard: Page "LyL NewItemVariant";
    begin
        if not CanOpenVariantDraft(SalesLine, Item) then
            exit;

        GetOrCreateLineDraft(SalesLine, Item, Draft);

        VariantCard.SetRecord(Draft);
        VariantCard.Run();
    end;

    /// <summary>
    /// Mismas validaciones que el "Acabados" de LyL: línea de artículo, que no
    /// sea un ensamble y que el artículo tenga clase de variante.
    /// </summary>
    local procedure CanOpenVariantDraft(SalesLine: Record "Sales Line"; var Item: Record Item): Boolean
    var
        BOMComponent: Record "BOM Component";
        NotItemLineMsg: Label 'Seleccione una línea de tipo Artículo.';
        IsAssemblyMsg: Label 'El artículo es un ensamble.';
        NoClassMsg: Label 'El artículo no tiene clase de variante asignada.';
    begin
        if (SalesLine.Type <> SalesLine.Type::Item) or (SalesLine."No." = '') then begin
            Message(NotItemLineMsg);
            exit(false);
        end;
        Item.Get(SalesLine."No.");

        BOMComponent.SetRange("Parent Item No.", SalesLine."No.");
        if not BOMComponent.IsEmpty() then begin
            Message(IsAssemblyMsg);
            exit(false);
        end;

        if Item."LyL VariantClass" = 0 then begin
            Message(NoClassMsg);
            exit(false);
        end;

        exit(true);
    end;

    /// <summary>
    /// Devuelve el borrador de la línea: el existente con el código de la línea,
    /// o uno nuevo preparado a partir de la variante de la línea.
    /// </summary>
    local procedure GetOrCreateLineDraft(SalesLine: Record "Sales Line"; Item: Record Item; var Draft: Record "LyL ItemVariant")
    begin
        // (3) Línea sin variante: borrador nuevo con código '0' (igual que LyL).
        if SalesLine."Variant Code" = '' then begin
            CreateLineDraft(SalesLine, Item, NoVariantTok, Draft);
            exit;
        end;

        // (1) Ya existe un borrador de esta línea con el código de la línea.
        if FindLineDraft(SalesLine, Item, Draft) then
            exit;

        // (2) Prepararlo a partir de la variante de la línea.
        PrepareDraftFromLineVariant(SalesLine, Item, Draft);
    end;

    local procedure FindLineDraft(SalesLine: Record "Sales Line"; Item: Record Item; var Draft: Record "LyL ItemVariant"): Boolean
    begin
        Draft.Reset();
        Draft.SetRange(VariantCode, SalesLine."Variant Code");
        Draft.SetRange(ItemId, SalesLine."No.");
        Draft.SetRange(ClassId, Item."LyL VariantClass");
        Draft.SetRange(DocumentNo, SalesLine."Document No.");
        Draft.SetRange(LineNo, SalesLine."Line No.");
        Draft.SetRange(DocumentType, SalesDocTypeTok);
        exit(Draft.FindFirst());
    end;

    local procedure PrepareDraftFromLineVariant(SalesLine: Record "Sales Line"; Item: Record Item; var Draft: Record "LyL ItemVariant")
    var
        ItemVariant: Record "Item Variant";
        SourceDraft: Record "LyL ItemVariant";
    begin
        // (2c) El código de la línea no existe como Item Variant: se muestra igual.
        if not ItemVariant.Get(SalesLine."No.", SalesLine."Variant Code") then begin
            CreateLineDraft(SalesLine, Item, SalesLine."Variant Code", Draft);
            exit;
        end;

        // (2c) Variante sin registro de LyL (p. ej. creada a mano).
        if not FindRegisteringDraft(ItemVariant, SourceDraft) then begin
            CreateLineDraft(SalesLine, Item, ItemVariant.Code, Draft);
            exit;
        end;

        // (2a) La variante se registró desde esta misma línea, pero su borrador
        //      no quedó con el código: se reutiliza poniéndole el código real.
        if IsDraftOfLine(SourceDraft, SalesLine, Item) then begin
            SourceDraft.VariantCode := ItemVariant.Code;
            SourceDraft.consecutive := ItemVariant."LyL Consecutive";
            SourceDraft.Modify();
            Draft := SourceDraft;
            exit;
        end;

        // (2b) Borrador nuevo para esta línea, copia de la variante registrada.
        InitLineDraft(SalesLine, Item, ItemVariant.Code, Draft);
        Draft.consecutive := ItemVariant."LyL Consecutive";
        Draft.PrecioFOB := SourceDraft.PrecioFOB;
        if SourceDraft.variantGenCode <> '' then
            Draft.variantGenCode := SourceDraft.variantGenCode
        else
            Draft.variantGenCode := ItemVariant."LyL VariantGenCode";
        Draft.Insert();
        CopyDraftDetails(SourceDraft, Draft);
    end;

    /// <summary>
    /// Borrador (LyL ItemVariant) con el que LyL registró la variante: el que
    /// apunta el campo "LyL IdVariant" de la Item Variant.
    /// </summary>
    local procedure FindRegisteringDraft(ItemVariant: Record "Item Variant"; var SourceDraft: Record "LyL ItemVariant"): Boolean
    begin
        if ItemVariant."LyL IdVariant" = 0 then
            exit(false);
        if not SourceDraft.Get(ItemVariant."LyL IdVariant") then
            exit(false);
        exit(SourceDraft.ItemId = ItemVariant."Item No.");
    end;

    local procedure IsDraftOfLine(Draft: Record "LyL ItemVariant"; SalesLine: Record "Sales Line"; Item: Record Item): Boolean
    begin
        exit((Draft.DocumentType = SalesDocTypeTok) and
             (Draft.DocumentNo = SalesLine."Document No.") and
             (Draft.LineNo = SalesLine."Line No.") and
             (Draft.ItemId = SalesLine."No.") and
             (Draft.ClassId = Item."LyL VariantClass"));
    end;

    local procedure CreateLineDraft(SalesLine: Record "Sales Line"; Item: Record Item; VariantCode: Code[10]; var Draft: Record "LyL ItemVariant")
    begin
        InitLineDraft(SalesLine, Item, VariantCode, Draft);
        Draft.Insert();
    end;

    /// <summary>
    /// Inicializa un borrador de validación ligado a la línea de venta, con los
    /// mismos valores que pone LyL en su botón "Acabados".
    /// </summary>
    local procedure InitLineDraft(SalesLine: Record "Sales Line"; Item: Record Item; VariantCode: Code[10]; var Draft: Record "LyL ItemVariant")
    begin
        // Clear (y no solo Init) para que el ID autoincremental vuelva a 0.
        Clear(Draft);
        Draft.Init();
        Draft.ClassId := Item."LyL VariantClass";
        Draft.ItemId := SalesLine."No.";
        Draft.VariantCode := VariantCode;
        Draft.VariantDescription := ValidationTok;
        Draft.LineNo := SalesLine."Line No.";
        Draft.DocumentNo := SalesLine."Document No.";
        Draft.DocumentType := SalesDocTypeTok;
    end;

    /// <summary>
    /// Copia las especificaciones (acabados) de un borrador a otro, con los
    /// mismos campos que copia LyL en la cotización.
    /// </summary>
    local procedure CopyDraftDetails(SourceDraft: Record "LyL ItemVariant"; TargetDraft: Record "LyL ItemVariant")
    var
        SourceDetail: Record "LyL ItemVariantDetails";
        NewDetail: Record "LyL ItemVariantDetails";
    begin
        SourceDetail.SetRange(VariantId, SourceDraft.ID);
        if SourceDetail.FindSet() then
            repeat
                Clear(NewDetail);
                NewDetail.Init();
                NewDetail.SpecID := SourceDetail.SpecID;
                NewDetail.SpecDescription := SourceDetail.SpecDescription;
                NewDetail.FeatureID := SourceDetail.FeatureID;
                NewDetail.FeatureDescription := SourceDetail.FeatureDescription;
                NewDetail.FeatureDetailID := SourceDetail.FeatureDetailID;
                NewDetail.FeatureDetailDescription := SourceDetail.FeatureDetailDescription;
                NewDetail.FeatureCode := SourceDetail.FeatureCode;
                NewDetail.IdClass := TargetDraft.ClassId;
                NewDetail.ItemID := TargetDraft.ItemId;
                NewDetail.VariantId := TargetDraft.ID;
                NewDetail.Level4ID := SourceDetail.Level4ID;
                NewDetail.Level5 := SourceDetail.Level5;
                NewDetail.MonedaLP := SourceDetail.MonedaLP;
                NewDetail.NewFeatureDetailID := SourceDetail.NewFeatureDetailID;
                NewDetail.PriceLP := SourceDetail.PriceLP;
                NewDetail.Insert();
            until SourceDetail.Next() = 0;
    end;
}
