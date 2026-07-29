// =============================================================================
// Page (API): BDT Payment Journal Line API (50102)
// -----------------------------------------------------------------------------
// Expone la tabla estándar "Gen. Journal Line" (81) FILTRADA al diario de pagos
// (plantilla PAGOS / sección TESORERIA) como entidad OData v4, para leer y
// escribir sus líneas desde un flujo de Power Automate.
//
// Ruta en BC (de dónde salen estos datos):
//   General Journal Batches (251) -> Gen. Journal Batch (232) = TESORERIA
//   -> Payment Journal (256, Worksheet) -> Gen. Journal Line (81)
//
// Diferencias con la API 50100 ("genJournalLines"):
//   * Esta entidad ("paymentJournalLines") SOLO ve el diario PAGOS/TESORERIA
//     (filtro fijo en SourceTableView), no todas las líneas de diario.
//   * Expone un conjunto reducido de campos (los solicitados para el flujo),
//     incluido el campo de localización Colombia "D365L CO Third No." (tercero).
//
// Nombres en español (importante):
//   En una API personalizada, Power Automate muestra el NOMBRE DE LA PROPIEDAD
//   JSON (el nombre del control en AL), no el Caption. Por eso cada campo se
//   nombra en español (camelCase, sin acentos) y además lleva el Caption con el
//   texto de BC.
//
// Clave OData:
//   SystemId ('id'), estable; Power Automate no necesita conocer el "Line No.".
//   El "Line No." lo asigna el servidor en OnInsertRecord (último + 10000).
//
// Endpoint (entorno online):
//   .../api/bodhitri/pagos/v1.0/companies({id})/paymentJournalLines
//
// Registro/posting: FUERA de esta API (se registra dentro de BC).
// =============================================================================
page 50131 "BDT Payment Journal Line API"
{
    PageType = API;
    Caption = 'Payment Journal Lines API';
    APIPublisher = 'bodhitri';
    APIGroup = 'pagos';
    APIVersion = 'v1.0';
    EntityName = 'paymentJournalLine';
    EntitySetName = 'paymentJournalLines';
    EntityCaption = 'Payment Journal Line';
    EntitySetCaption = 'Payment Journal Lines';
    SourceTable = "Gen. Journal Line";
    DelayedInsert = true;
    ODataKeyFields = SystemId;
    Extensible = false;

    // Filtro fijo: SOLO el diario de pagos (plantilla PAGOS, sección TESORERIA).
    // Estos literales deben coincidir con PaymentTemplateTok/PaymentBatchTok de
    // abajo (SourceTableView exige constantes en tiempo de compilación).
    SourceTableView = where("Journal Template Name" = const('PAGOS'),
                            "Journal Batch Name" = const('TESORERIA'));

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                // --- Clave estable para Power Automate (no editable) -----------
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                    Editable = false;
                }

                // --- Campos solicitados (orden = orden de validación) ----------
                field(fechaRegistro; Rec."Posting Date")
                {
                    Caption = 'Fecha registro';
                }
                field(tipoMovimiento; Rec."Account Type")
                {
                    Caption = 'Tipo mov.';
                }
                field(numeroCuenta; Rec."Account No.")
                {
                    Caption = 'N.º cuenta';
                }
                field(codigoFormaPago; Rec."Payment Method Code")
                {
                    Caption = 'Cód. forma pago';
                }
                field(importe; Rec.Amount)
                {
                    Caption = 'Importe';
                }
                field(tipoContrapartida; Rec."Bal. Account Type")
                {
                    Caption = 'Tipo contrapartida';
                }
                field(cuentaContrapartida; Rec."Bal. Account No.")
                {
                    Caption = 'Cta. contrapartida';
                }
                // Campo de la localización Colombia (D365LATAM), tabla ext.
                // "D365L CO GenJournalLineExt" (campo 66837, Code[35]).
                field(numeroTercero; Rec."D365L CO Third No.")
                {
                    Caption = 'N.º tercero';
                }

                // --- Técnicos (solo lectura) -----------------------------------
                // El servidor asigna el "Line No." en OnInsertRecord; se expone
                // solo lectura para que el flujo lo lea de vuelta tras crear.
                field(numeroLinea; Rec."Line No.")
                {
                    Caption = 'N.º línea';
                    Editable = false;
                }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Caption = 'Última modificación';
                    Editable = false;
                }
            }
        }
    }

    var
        // Diario fijo de esta API. Mantener sincronizados con SourceTableView.
        PaymentTemplateTok: Label 'PAGOS', Locked = true;
        PaymentBatchTok: Label 'TESORERIA', Locked = true;

    /// <summary>
    /// Al crear una línea: fija Plantilla/Sección del diario de pagos (en orden:
    /// plantilla primero, luego sección), asigna el "Line No." de servidor
    /// (último de ese diario + 10000) y usa la fecha de trabajo si no llega
    /// "fechaRegistro".
    /// </summary>
    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        GenJnlLine: Record "Gen. Journal Line";
    begin
        // Plantilla primero, luego Sección (la validación de la Sección exige que
        // la Plantilla ya esté puesta en el registro).
        Rec.Validate("Journal Template Name", PaymentTemplateTok);
        Rec.Validate("Journal Batch Name", PaymentBatchTok);

        if Rec."Line No." = 0 then begin
            GenJnlLine.SetRange("Journal Template Name", Rec."Journal Template Name");
            GenJnlLine.SetRange("Journal Batch Name", Rec."Journal Batch Name");
            if GenJnlLine.FindLast() then
                Rec."Line No." := GenJnlLine."Line No." + 10000
            else
                Rec."Line No." := 10000;
        end;

        if Rec."Posting Date" = 0D then
            Rec."Posting Date" := WorkDate();
    end;
}
