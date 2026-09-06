// =============================================================================
// Page (API): BDT Purchase Header API (50133)
// -----------------------------------------------------------------------------
// Expone la tabla estándar "Purchase Header" (38) como entidad OData v4 para
// leer / crear / actualizar cabeceras de compra (facturas de compra) desde un
// flujo de Power Automate.
//
// Origen en BC (de dónde salen estos datos):
//   Purchase Invoice (51, Document) -> Purchase Header (38)
//   Son los mismos campos de la pestaña "General" de la ficha Factura compra.
//
// Campos solicitados para el flujo (todos estándar de Base Application; esta
// API solo los expone, no los crea):
//   Buy-from Vendor No.   (2,   Code[20])  -> numeroDeProveedor
//   Document Date         (99,  Date)      -> fechaEmisionDocumento
//   Invoice Received Date (175, Date)      -> fechaRecepcionFactura
//   Vendor Invoice No.    (68,  Code[35])  -> numeroFacturaProveedor
//   Posting Description   (22,  Text[100]) -> textoDeRegistro
//   Posting No. Series    (108, Code[20])  -> numeroSerieRegistro
//
// Nombres en español (importante):
//   En una API personalizada, Power Automate muestra el NOMBRE DE LA PROPIEDAD
//   JSON (el nombre del control en AL), no el Caption. Por eso cada campo se
//   nombra en español (camelCase, sin acentos) y además lleva el Caption con el
//   texto de BC.
//
// Identificación del documento:
//   * Clave OData estable: SystemId (campo 'id'); es la que usa el conector de
//     Business Central para leer/editar el registro.
//   * 'tipoDocumento' + 'numero' (= "Document Type" + "No.", la clave primaria
//     real) para localizar/filtrar, p. ej.
//       .../purchaseHeaders?$filter=tipoDocumento eq 'Invoice' and numero eq 'DS0661'
//   * 'tipoDocumento' viaja como texto: 'Quote', 'Order', 'Invoice',
//     'Credit Memo', 'Blanket Order', 'Return Order'.
//
// Endpoint (entorno online):
//   .../api/bodhitri/compras/v1.0/companies({id})/purchaseHeaders
//
// Alcance de la entidad:
//   NO lleva filtro fijo, así que ve todos los documentos de compra. Si el flujo
//   solo debe ver facturas, descomentar la línea SourceTableView de abajo.
//
// Al crear (POST):
//   * Si el flujo NO envía 'tipoDocumento', OnInsertRecord lo fija en Invoice
//     (el valor por defecto de la tabla sería Quote / Oferta).
//   * Si NO envía 'numero', BC lo autonumera en el OnInsert de la tabla con la
//     serie de "Compras y pagos" (igual que pulsar "Nuevo" en Facturas compra).
//
// Registro/posting: FUERA de esta API (se registra dentro de BC).
// =============================================================================
page 50133 "BDT Purchase Header API"
{
    PageType = API;
    Caption = 'Purchase Headers API';
    APIPublisher = 'bodhitri';
    APIGroup = 'compras';
    APIVersion = 'v1.0';
    EntityName = 'purchaseHeader';
    EntitySetName = 'purchaseHeaders';
    EntityCaption = 'Purchase Header';
    EntitySetCaption = 'Purchase Headers';
    SourceTable = "Purchase Header";
    DelayedInsert = true;
    ODataKeyFields = SystemId;
    Extensible = false;

    // Descomentar para que la entidad SOLO vea facturas de compra:
    // SourceTableView = where("Document Type" = const(Invoice));

    layout
    {
        area(Content)
        {
            repeater(Documents)
            {
                // --- Clave estable para Power Automate (no editable) -----------
                // 'id' se deja como 'id': es la clave OData (SystemId) que el
                // conector de Business Central usa para leer/editar el registro.
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                    Editable = false;
                }

                // --- Identificación del documento -----------------------------
                // Enviarlos primero: el tipo y el número deciden la serie de
                // numeración y a qué documento se aplican los demás campos.
                field(tipoDocumento; Rec."Document Type")
                {
                    Caption = 'Tipo documento';
                }
                field(numero; Rec."No.")
                {
                    Caption = 'N.º';
                }

                // --- Campos solicitados (orden = orden de validación) ----------
                // El proveedor va antes que las fechas: su validación trae
                // condiciones de pago, dirección, moneda, etc., y la fecha del
                // documento recalcula vencimiento y descuento con esos datos.
                field(numeroDeProveedor; Rec."Buy-from Vendor No.")
                {
                    Caption = 'N.º de proveedor';
                }
                field(fechaEmisionDocumento; Rec."Document Date")
                {
                    Caption = 'Fecha emisión documento';
                }
                field(fechaRecepcionFactura; Rec."Invoice Received Date")
                {
                    Caption = 'Fecha de recepción de factura';
                }
                field(numeroFacturaProveedor; Rec."Vendor Invoice No.")
                {
                    Caption = 'Nº factura proveedor';
                }
                field(textoDeRegistro; Rec."Posting Description")
                {
                    Caption = 'Texto de registro';
                }
                field(numeroSerieRegistro; Rec."Posting No. Series")
                {
                    Caption = 'No. Serie Registro';
                }

            }
        }
    }

    /// <summary>
    /// Al crear un documento: si el flujo no envía 'tipoDocumento', lo fija en
    /// Invoice (Factura), porque el valor por defecto de la tabla es Quote
    /// (Oferta) y el flujo trabaja con facturas de compra. Enviar el tipo
    /// explícitamente sigue funcionando para cualquier otro documento.
    /// El "No." lo asigna el OnInsert de la tabla desde la serie de "Compras y
    /// pagos" cuando llega vacío.
    /// </summary>
    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        if Rec."Document Type" = Rec."Document Type"::Quote then
            Rec."Document Type" := Rec."Document Type"::Invoice;
    end;
}
