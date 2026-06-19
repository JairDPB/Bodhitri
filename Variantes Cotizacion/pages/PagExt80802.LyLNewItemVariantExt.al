// =============================================================================
// PageExtension: LyL NewItemVariant (80708) — "Registro de Variante"
// -----------------------------------------------------------------------------
// Agrega (de forma aditiva) una acción que genera las líneas de especificación
// (LyL ItemVariantDetails, vistas en el ListPart 80707) descomponiendo la
// "Descripción de Variante" de la variante. La lógica vive en el codeunit
// "BDT Variant Detail Builder"; aquí solo está el disparador en la ficha.
// =============================================================================
pageextension 80802 "BDT LyL NewItemVariant Ext" extends "LyL NewItemVariant"
{
    actions
    {
        addlast(Processing)
        {
            action(BDTGenerateDetailsFromDesc)
            {
                Caption = 'Generar detalles desde descripción';
                ToolTip = 'Descompone la Descripción de Variante de este registro y genera/regenera las líneas de especificación (Acabado y Tipo de Acabado) emparejándolas con las tablas maestras.';
                ApplicationArea = All;
                Image = Action;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    DetailBuilder: Codeunit "BDT Variant Detail Builder";
                    ConfirmFillQst: Label '¿Rellenar el Acabado y el Tipo de Acabado de las líneas a partir de la Descripción de Variante?';
                begin
                    if not Confirm(ConfirmFillQst, false) then
                        exit;

                    DetailBuilder.FillDetailsFromDescription(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
