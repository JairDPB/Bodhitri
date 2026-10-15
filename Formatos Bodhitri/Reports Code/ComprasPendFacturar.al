// ============================================================================
//  Reporte 2: Pedidos de compra PENDIENTES POR FACTURAR, con sus líneas.
//  Base: Purchase Header (38) -> Purchase Line (39), Document Type = Order.
//  Muestra: N.º de pedido, proveedor, y por línea Cantidad a facturar
//  (Qty. to Invoice) y Cantidad facturada (Quantity Invoiced).
//  Filtro: solo líneas con cantidad pendiente por facturar (Facturada < Cantidad).
// ============================================================================
report 50103 "BDT Compras Pend Facturar"
{
    Caption = 'Compras pendientes por facturar';
    ApplicationArea = All;
    UsageCategory = ReportsAndAnalysis;
    DefaultRenderingLayout = "ComprasPendFacturarLayout";

    dataset
    {
        dataitem(PurchaseLine; "Purchase Line")
        {
            DataItemTableView = where("Document Type" = const(Order));
            RequestFilterFields = "Document No.", "Buy-from Vendor No.", "No.";

            column(OrderNo; "Document No.") { }
            column(VendorName; BuyFromVendorName) { }
            column(LineNo; "Line No.") { }
            column(LineType; Format(Type)) { }
            column(ItemNo; "No.") { }
            column(Description; Description) { }
            column(Quantity; Quantity) { }
            column(QtyToInvoice; "Qty. to Invoice") { }
            column(QuantityInvoiced; "Quantity Invoiced") { }

            trigger OnAfterGetRecord()
            begin
                // Omitir líneas de comentario y las ya facturadas por completo.
                if (Quantity = 0) or ("Quantity Invoiced" >= Quantity) then
                    CurrReport.Skip();

                BuyFromVendorName := '';
                if PurchaseHeader.Get("Document Type", "Document No.") then
                    BuyFromVendorName := PurchaseHeader."Buy-from Vendor Name";
            end;
        }
    }

    rendering
    {
        layout("ComprasPendFacturarLayout")
        {
            Type = RDLC;
            LayoutFile = 'Reports/ComprasPendFacturar.rdl';
            Caption = 'Compras pendientes por facturar';
        }
    }

    var
        PurchaseHeader: Record "Purchase Header";
        BuyFromVendorName: Text[100];
}
