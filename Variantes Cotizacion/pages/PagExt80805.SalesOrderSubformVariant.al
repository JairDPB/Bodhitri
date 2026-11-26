// =============================================================================
// PageExtension: Sales Order Subform (46) — "Acabados" para pedidos
// -----------------------------------------------------------------------------
// Hace que el botón "Acabados" del PEDIDO funcione igual que en la COTIZACIÓN:
//   • Oculta el "Acabados" simple de LyL (action "LyL newAction" de la
//     Pag-Ext 80701), que creaba el borrador con Código Variante = '0' cuando
//     no encontraba uno de la línea con su mismo código.
//   • Agrega un "Acabados" que usa la lógica completa (codeunit
//     "BDT Order Variant Mgt"): muestra el código de la variante de la línea y
//     copia sus especificaciones, sea cual sea su nivel (3, 4...).
// =============================================================================
pageextension 80805 "BDT SalesOrderSubform Variant" extends "Sales Order Subform"
{
    actions
    {
        // Ocultar el "Acabados" simple de LyL en el pedido.
        modify("LyL newAction")
        {
            Visible = false;
        }

        addlast("&Line")
        {
            action(BDTAcabadosOrder)
            {
                Caption = 'Acabados';
                ToolTip = 'Abre el Registro de Variante del artículo copiando la variante seleccionada en la línea (código y especificaciones), igual que en la cotización.';
                ApplicationArea = All;
                Image = Action;

                trigger OnAction()
                var
                    OrderVariantMgt: Codeunit "BDT Order Variant Mgt";
                begin
                    OrderVariantMgt.OpenVariantDraft(Rec);
                end;
            }
        }
    }
}
