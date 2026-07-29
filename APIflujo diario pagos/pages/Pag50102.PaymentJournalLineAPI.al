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
                // 'id' se deja como 'id': es la clave OData (SystemId) que el
                // conector de Business Central usa para leer/editar/borrar la línea.
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                    Editable = false;
                }

                // --- Campos solicitados (orden = orden de validación) ----------
                field(fechaDeRegistro; Rec."Posting Date")
                {
                    Caption = 'Fecha de registro';
                }
                field(tipoDeMovimiento; Rec."Account Type")
                {
                    Caption = 'Tipo de movimiento';
                }
                field(numeroDeCuenta; Rec."Account No.")
                {
                    Caption = 'Número de cuenta';
                }
                field(codigoFormaDePago; Rec."Payment Method Code")
                {
                    Caption = 'Código de forma de pago';
                }
                field(importe; Rec.Amount)
                {
                    Caption = 'Importe';
                }
                field(tipoDeContrapartida; Rec."Bal. Account Type")
                {
                    Caption = 'Tipo de contrapartida';
                }
                field(cuentaDeContrapartida; Rec."Bal. Account No.")
                {
                    Caption = 'Cuenta de contrapartida';
                }
                // Campo de la localización Colombia (D365LATAM), tabla ext.
                // "D365L CO GenJournalLineExt" (campo 66837, Code[35]).
                field(numeroDeTercero; Rec."D365L CO Third No.")
                {
                    Caption = 'Número de tercero';
                }

                // --- Técnicos (solo lectura) -----------------------------------
                // El servidor asigna el "Line No." en OnInsertRecord; se expone
                // solo lectura para que el flujo lo lea de vuelta tras crear.
                field(numeroDeLinea; Rec."Line No.")
                {
                    Caption = 'Número de línea';
                    Editable = false;
                }
                field(ultimaModificacion; Rec.SystemModifiedAt)
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
