// =============================================================================
// Page (API): BDT Gen. Journal Line API (50100)
// -----------------------------------------------------------------------------
// Expone la tabla estándar "Gen. Journal Line" (81) como una entidad OData v4
// para consumirla desde Power Automate y crear líneas de diario (flujo diario
// de pagos) a partir de los valores de una lista de SharePoint.
//
// Patrón de uso:
//   1 fila de la lista de SharePoint  ->  1 POST a esta entidad  ->  1 línea
//   de "Gen. Journal Line" en el diario indicado (Template + Batch).
//
// Diseño:
//   * La clave OData es el SystemId (estable), NO la clave primaria de la tabla
//     (Template+Batch+Line No.). Así Power Automate no necesita conocer el
//     "Line No." para crear/leer/actualizar la línea.
//   * El "Line No." se asigna SOLO en el servidor (OnInsertRecord), tomando el
//     último de ese diario + 10000. SharePoint NO debe enviarlo.
//   * El Template y el Batch SÍ viajan desde SharePoint en cada fila.
//   * Las validaciones de tabla se ejecutan al asignar cada campo (igual que en
//     la ficha del diario), por eso resuelven proveedor/banco, signo de importe,
//     aplicación a documentos, etc. El orden de declaración de los campos sigue
//     el orden de dependencia recomendado para enviarlos.
//
// Endpoint (entorno online):
//   .../api/bodhitri/pagos/v1.0/companies({id})/genJournalLines
//
// Registro/posting: queda FUERA de esta API (se registra en BC). Esta entidad
// solo CREA/lee/edita/borra líneas no registradas.
// =============================================================================
page 50100 "BDT Gen. Journal Line API"
{
    PageType = API;
    Caption = 'Gen. Journal Lines API';
    APIPublisher = 'bodhitri';
    APIGroup = 'pagos';
    APIVersion = 'v1.0';
    EntityName = 'genJournalLine';
    EntitySetName = 'genJournalLines';
    EntityCaption = 'Gen. Journal Line';
    EntitySetCaption = 'Gen. Journal Lines';
    SourceTable = "Gen. Journal Line";
    DelayedInsert = true;
    ODataKeyFields = SystemId;
    Extensible = false;

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

                // --- Diario destino (vienen desde SharePoint) ------------------
                // Se enlazan a variables globales (no directamente al Rec) para
                // poder aplicarlas EN ORDEN (plantilla -> sección) dentro de
                // OnInsertRecord, sin importar en qué orden las envíe Power
                // Automate. Así se evita el error "The Gen. Journal Template does
                // not exist. Name=''" que ocurre si la sección se valida antes
                // que la plantilla.
                field(journalTemplateName; GJTemplateName)
                {
                    Caption = 'Journal Template Name';
                }
                field(journalBatchName; GJBatchName)
                {
                    Caption = 'Journal Batch Name';
                }
                // El servidor lo asigna en OnInsertRecord; se expone solo lectura
                // para que Power Automate pueda leerlo de vuelta tras crear.
                field(lineNumber; Rec."Line No.")
                {
                    Caption = 'Line No.';
                    Editable = false;
                }

                // --- Cabecera de la línea --------------------------------------
                field(postingDate; Rec."Posting Date")
                {
                    Caption = 'Fecha de registro';
                }
                field(documentDate; Rec."Document Date")
                {
                    Caption = 'Document Date';
                }
                field(documentType; Rec."Document Type")
                {
                    Caption = 'Document Type';
                }
                field(documentNumber; Rec."Document No.")
                {
                    Caption = 'Document No.';
                }
                field(externalDocumentNumber; Rec."External Document No.")
                {
                    Caption = 'External Document No.';
                }

                // --- Cuenta principal ------------------------------------------
                field(accountType; Rec."Account Type")
                {
                    Caption = 'Account Type';
                }
                field(accountNumber; Rec."Account No.")
                {
                    Caption = 'Account No.';
                }
                field(description; Rec.Description)
                {
                    Caption = 'Description';
                }

                // --- Importes ---------------------------------------------------
                field(currencyCode; Rec."Currency Code")
                {
                    Caption = 'Currency Code';
                }
                field(amount; Rec.Amount)
                {
                    Caption = 'Amount';
                }

                // --- Contrapartida (banco / caja, etc.) ------------------------
                field(balanceAccountType; Rec."Bal. Account Type")
                {
                    Caption = 'Bal. Account Type';
                }
                field(balanceAccountNumber; Rec."Bal. Account No.")
                {
                    Caption = 'Bal. Account No.';
                }

                // --- Aplicación a documentos (saldar facturas) -----------------
                field(appliesToDocType; Rec."Applies-to Doc. Type")
                {
                    Caption = 'Applies-to Doc. Type';
                }
                field(appliesToDocNumber; Rec."Applies-to Doc. No.")
                {
                    Caption = 'Applies-to Doc. No.';
                }
                field(appliesToID; Rec."Applies-to ID")
                {
                    Caption = 'Applies-to ID';
                }

                // --- Datos de pago ---------------------------------------------
                field(dueDate; Rec."Due Date")
                {
                    Caption = 'Due Date';
                }
                field(paymentMethodCode; Rec."Payment Method Code")
                {
                    Caption = 'Payment Method Code';
                }
                field(paymentReference; Rec."Payment Reference")
                {
                    Caption = 'Payment Reference';
                }
                field(recipientBankAccount; Rec."Recipient Bank Account")
                {
                    Caption = 'Recipient Bank Account';
                }
                field(messageToRecipient; Rec."Message to Recipient")
                {
                    Caption = 'Message to Recipient';
                }

                // --- Dimensiones (opcional) ------------------------------------
                field(shortcutDimension1Code; Rec."Shortcut Dimension 1 Code")
                {
                    Caption = 'Shortcut Dimension 1 Code';
                }
                field(shortcutDimension2Code; Rec."Shortcut Dimension 2 Code")
                {
                    Caption = 'Shortcut Dimension 2 Code';
                }

                // --- Auditoría (solo lectura) ----------------------------------
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Caption = 'Last Modified Date-Time';
                    Editable = false;
                }
            }
        }
    }

    var
        GJTemplateName: Code[10];
        GJBatchName: Code[10];

    /// <summary>
    /// Al leer una línea existente, copia Plantilla/Sección del Rec a las
    /// variables globales para que la API las devuelva en las respuestas (GET).
    /// </summary>
    trigger OnAfterGetRecord()
    begin
        GJTemplateName := Rec."Journal Template Name";
        GJBatchName := Rec."Journal Batch Name";
    end;

    /// <summary>
    /// Construye la clave de la línea ANTES de insertar:
    ///  1) Valida Plantilla y, luego, Sección (orden correcto, sin importar el
    ///     orden del payload). Da errores claros si faltan.
    ///  2) Asigna el "Line No." de servidor: último de ese diario + 10000.
    ///  3) Pone la fecha de trabajo en "Posting Date" si la fila no la trae.
    /// </summary>
    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        GenJnlLine: Record "Gen. Journal Line";
        MissingTemplateErr: Label 'Debe enviar "journalTemplateName" (nombre de la plantilla del diario, p. ej. PAGOS).';
        MissingBatchErr: Label 'Debe enviar "journalBatchName" (nombre de la sección del diario, p. ej. TESORERIA).';
    begin
        if GJTemplateName = '' then
            Error(MissingTemplateErr);
        if GJBatchName = '' then
            Error(MissingBatchErr);

        // Plantilla primero, luego Sección (la validación de la Sección exige que
        // la Plantilla ya esté puesta en el registro).
        Rec.Validate("Journal Template Name", GJTemplateName);
        Rec.Validate("Journal Batch Name", GJBatchName);

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
