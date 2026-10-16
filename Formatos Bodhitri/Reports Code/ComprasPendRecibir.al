// ============================================================================
//  Reporte 1: Pedidos de compra PENDIENTES POR RECIBIR, con sus líneas.
//  Base: Purchase Header (38) -> Purchase Line (39), Document Type = Order.
//  Muestra: N.º de pedido, proveedor, y por línea Cantidad a recibir
//  (Qty. to Receive) y Cantidad recibida (Quantity Received).
//  Filtro: solo líneas con cantidad pendiente por recibir (Recibida < Cantidad).
// ============================================================================
report 50102 "BDT Compras Pend Recibir"
{
    Caption = 'Compras pendientes por recibir';
    ApplicationArea = All;
    UsageCategory = ReportsAndAnalysis;
    DefaultRenderingLayout = "ComprasPendRecibirLayout";

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
            column(QtyToReceive; "Qty. to Receive") { }
            column(QuantityReceived; "Quantity Received") { }
            column(FechaHoraDescarga; FechaHoraDescarga) { }

            trigger OnAfterGetRecord()
            begin
                // Omitir líneas de comentario y las ya recibidas por completo.
                if (Quantity = 0) or ("Quantity Received" >= Quantity) then
                    CurrReport.Skip();

                BuyFromVendorName := '';
                if PurchaseHeader.Get("Document Type", "Document No.") then
                    BuyFromVendorName := PurchaseHeader."Buy-from Vendor Name";
            end;
        }
    }

    rendering
    {
        layout("ComprasPendRecibirLayout")
        {
            Type = RDLC;
            LayoutFile = 'Reports/ComprasPendRecibir.rdl';
            Caption = 'Compras pendientes por recibir';
        }
    }

    var
        PurchaseHeader: Record "Purchase Header";
        BuyFromVendorName: Text[100];
        FechaHoraDescarga: Text[30];

    trigger OnPreReport()
    begin
        // Fecha y hora de generación del informe, en la zona horaria del usuario.
        FechaHoraDescarga := Format(CurrentDateTime, 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2><Filler Character,0>:<Minutes,2>:<Seconds,2>');
    end;
}
