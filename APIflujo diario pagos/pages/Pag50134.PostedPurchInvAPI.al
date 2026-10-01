// =============================================================================
// Page (API): BDT Posted Purch. Inv. API (50134)
// -----------------------------------------------------------------------------
// Expone el histórico de facturas de compra REGISTRADAS, tabla estándar
// "Purch. Inv. Header" (122), como entidad OData v4 de SOLO LECTURA, para
// sincronizarlo con una lista de SharePoint desde Power Automate.
//
// Origen en BC:
//   Facturas compra registradas (146, List) -> Purch. Inv. Header (122)
//   Cada vez que se registra una factura de compra, BC inserta aquí su cabecera.
//
// Campos solicitados (todos estándar de Base Application):
//   No.                    (3,  Code[20])            -> numero
//   Buy-from Vendor No.    (2,  Code[20])            -> numeroDeProveedor
//   Buy-from Vendor Name   (79, Text[100])           -> nombreDeProveedor
//   Vendor Invoice No.     (68, Code[35])            -> numeroFacturaProveedor
//   Amount Including VAT   (61, Decimal, FlowField)  -> importeIvaIncluido
//
// Añadidos para que la sincronización sea correcta:
//   Currency Code (32) -> codigoDivisa. El importe está en la MONEDA DE LA
//     FACTURA, no en pesos: una factura en USD trae el importe en dólares. Sin
//     la divisa, la lista de SharePoint mezclaría monedas sin que se note.
//     Vacío = moneda local.
//   SystemCreatedAt    -> fechaCreacion. Momento en que se registró la factura.
//     Es la referencia fiable para traer "lo nuevo desde la última vez": la
//     fecha de registro no sirve para eso, porque una factura puede registrarse
//     hoy con fecha contable del mes pasado.
//
// ¿Por qué no usar la API estándar microsoft/automate/v1.0/postedPurchaseInvoices
// (página 9971), que lee la misma tabla?
//   * Sus campos están en inglés; en Power Automate se ve el nombre de la
//     propiedad JSON, no el Caption.
//   * No expone SystemCreatedAt, así que no permite una reconciliación
//     incremental fiable.
//   * Lleva DataAccessIntent = ReadOnly (lee de la réplica). Esta página NO lo
//     lleva a propósito: el flujo lee la factura segundos después de registrarse
//     y la réplica puede ir por detrás, devolviendo NotFound.
//
// Endpoint (entorno online):
//   .../api/bodhitri/compras/v1.0/companies({id})/postedPurchaseInvoices
//
// Solo lectura: una factura registrada no se crea, modifica ni borra por API.
// =============================================================================
page 50134 "BDT Posted Purch. Inv. API"
{
    PageType = API;
    Caption = 'Posted Purchase Invoices API';
    APIPublisher = 'bodhitri';
    APIGroup = 'compras';
    APIVersion = 'v1.0';
    EntityName = 'postedPurchaseInvoice';
    EntitySetName = 'postedPurchaseInvoices';
    EntityCaption = 'Posted Purchase Invoice';
    EntitySetCaption = 'Posted Purchase Invoices';
    SourceTable = "Purch. Inv. Header";
    ODataKeyFields = SystemId;
    Extensible = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Invoices)
            {
                // Clave OData (SystemId). Es la que el conector de Business
                // Central usa en "Obtener registro" y la que conviene guardar en
                // SharePoint para no duplicar filas.
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                }

                // --- Campos solicitados ----------------------------------------
                field(numero; Rec."No.")
                {
                    Caption = 'N.º';
                }
                field(numeroDeProveedor; Rec."Buy-from Vendor No.")
                {
                    Caption = 'Compra a-N.º proveedor';
                }
                field(nombreDeProveedor; Rec."Buy-from Vendor Name")
                {
                    Caption = 'Compra a-Nombre';
                }
                field(numeroFacturaProveedor; Rec."Vendor Invoice No.")
                {
                    Caption = 'N.º factura proveedor';
                }
                field(importePendiente; Rec."Remaining Amount")
                {
                    Caption = 'Importe pendiente';
                }

                // --- Añadidos para la sincronización ---------------------------
                field(codigoDivisa; Rec."Currency Code")
                {
                    Caption = 'Cód. divisa';
                }
                field(fechaCreacion; Rec.SystemCreatedAt)
                {
                    Caption = 'Fecha de creación';
                }
                field(ultimaModificacion; Rec.SystemModifiedAt)
                {
                    Caption = 'Última modificación';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        // "Amount Including VAT" es un FlowField: la suma de las líneas de la
        // factura registrada (Purch. Inv. Line). Calcularlo junto con la lectura
        // de cada registro evita una consulta aparte por fila.
        Rec.SetAutoCalcFields("Amount Including VAT");
    end;
}
