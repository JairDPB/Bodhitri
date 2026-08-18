// ============================================================================
//  Extiende el reporte de Cotización de Venta de "Ezgo Fields" (LyL Consultores)
//  para incluir la imagen del producto (Item.Picture, MediaSet) en cada línea.
//
//  Report base : 50201 "LyL Rep.CotizacionVenta"   (dataitem de líneas: "Line")
//  Layout      : Opción A -> el RDL se versiona dentro de esta app (bloque rendering).
//
//  Nota: si VS Code marca los tipos con error de namespace, usa Ctrl+. (Quick Fix)
//        para agregar los "using" (System.Sales.Document, System.Inventory.Item, etc.).
// ============================================================================
reportextension 50100 "Cotizacion Venta Img" extends "LyL Rep.CotizacionVenta"
{
    dataset
    {
        // "Line" es el dataitem de líneas (tabla Sales Line) del reporte 50201.
        add(Line)
        {
            // Imagen del producto en Base64 (se decodifica en el RDL).
            column(ItemPicture_Line; GetItemPictureBase64(Line))
            {
            }
            // Tipo MIME real de la imagen (para el control <Image> del RDL).
            column(ItemPictureMime_Line; GetItemPictureMime(Line))
            {
            }
        }
    }

    rendering
    {
        // Layout propio versionado en la app. Tras publicar, selecciónalo como
        // diseño del informe 50201 en "Selección de informes / Report Layout Selection".
        layout("CotizacionVentaEzgoBDT")
        {
            Type = RDLC;
            // La ruta es relativa a la RAÍZ del proyecto (carpeta de app.json), NO al .al.
            LayoutFile = 'Reports/Cotización Venta Ezgo.rdl';
            Caption = 'Cotización Venta Ezgo (Bodhitrí)';
        }

        // Variante ECUADOR: mismo report 50201, distinto diseño. Ambos layouts viven aquí
        // porque las columnas de imagen solo se agregan una vez al dataset del report base.
        layout("CotizacionVentaEcuadorBDT")
        {
            Type = RDLC;
            LayoutFile = 'Reports/COTIZACION EZGO ECUADOR.rdl';
            Caption = 'Cotización Venta Ezgo (ECUADOR)';
        }
    }

    local procedure GetItemPictureBase64(SalesLine: Record "Sales Line"): Text
    var
        Item: Record Item;
        TenantMedia: Record "Tenant Media";
        Base64Convert: Codeunit "Base64 Convert";
        InStr: InStream;
    begin
        if SalesLine.Type <> SalesLine.Type::Item then
            exit('');
        if not Item.Get(SalesLine."No.") then
            exit('');
        // MediaSet: se lee directo con .Count/.Item(); NO usar CalcFields (no es FlowField).
        if Item.Picture.Count = 0 then
            exit('');
        if not TenantMedia.Get(Item.Picture.Item(1)) then
            exit('');
        TenantMedia.CalcFields(Content);             // Content es Blob: hay que calcularlo
        if not TenantMedia.Content.HasValue() then
            exit('');
        TenantMedia.Content.CreateInStream(InStr);
        exit(Base64Convert.ToBase64(InStr));
    end;

    local procedure GetItemPictureMime(SalesLine: Record "Sales Line"): Text
    var
        Item: Record Item;
        TenantMedia: Record "Tenant Media";
    begin
        if SalesLine.Type <> SalesLine.Type::Item then
            exit('image/jpeg');
        if not Item.Get(SalesLine."No.") then
            exit('image/jpeg');
        if Item.Picture.Count = 0 then
            exit('image/jpeg');
        if TenantMedia.Get(Item.Picture.Item(1)) then
            if TenantMedia."Mime Type" <> '' then
                exit(TenantMedia."Mime Type");
        exit('image/jpeg');
    end;
}
