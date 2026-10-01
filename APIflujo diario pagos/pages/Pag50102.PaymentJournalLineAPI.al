
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
                field(TipoRegistroGen; Rec."Gen. Posting Type")
                {
                    Caption = 'Tipo de Registro Gen';
                }
                field(NDocumento; Rec."Document No.")
                {
                    Caption = 'Número de Documento';
                }
                field(LiqTipoDocumento; Rec."Applies-to Doc. Type")
                {
                    Caption = 'Tipo de Documento de Liquidación';
                }
                field(LiqNDocumento; Rec."Applies-to Doc. No.")
                {
                    Caption = 'Número de Documento de Liquidación';
                }
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
    // --- NUEVO BLOQUE: Lógica de autoincremento ---
    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        GenJournalLine: Record "Gen. Journal Line";
    begin
        Rec."Journal Template Name" := 'PAGOS';
        Rec."Journal Batch Name" := 'TESORERIA';

        // Siguiente N.º de línea del diario.
        //
        // Solo se calcula si la línea llega sin número: así, si el flujo decide
        // enviarlo explícitamente, se respeta en vez de pisarlo.
        //
        // LockTable() va JUSTO ANTES de la lectura, que es donde surte efecto:
        // marca el rango para que quede bloqueado al leerlo. Puesto antes de los
        // filtros no protege lo que hace falta. Sin ese bloqueo, dos inserciones
        // simultáneas leen el mismo "último" y calculan el mismo N.º de línea: el
        // "Aplicar a cada uno" de Power Automate corre hasta 20 iteraciones en
        // paralelo, así que el choque de clave primaria no es hipotético.
        //
        // No hace falta SetCurrentKey: (Plantilla, Sección, N.º línea) ya es la
        // clave primaria de la tabla, así que FindLast() devuelve por sí solo la
        // línea de mayor N.º dentro del diario filtrado.
        if Rec."Line No." = 0 then begin
            GenJournalLine.SetRange("Journal Template Name", Rec."Journal Template Name");
            GenJournalLine.SetRange("Journal Batch Name", Rec."Journal Batch Name");
            GenJournalLine.LockTable();
            if GenJournalLine.FindLast() then
                Rec."Line No." := GenJournalLine."Line No." + 10000
            else
                Rec."Line No." := 10000;
        end;

        // true = "insertar el registro". Es el valor por defecto del trigger, así
        // que se deja explícito solo por claridad.
        exit(true);
    end;
}
