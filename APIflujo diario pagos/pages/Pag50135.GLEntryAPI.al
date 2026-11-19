// =============================================================================
// Page (API): BDT G/L Entry API (50135)
// -----------------------------------------------------------------------------
// Expone los movimientos contables, tabla estándar "G/L Entry" (17), como
// entidad OData v4 de SOLO LECTURA para consumirlos desde Power Automate.
//
// Origen en BC:
//   Movimientos contables (General Ledger Entries, 20, List) -> G/L Entry (17)
//
// Campos solicitados:
//   Posting Date           (4,     Date)       -> fechaDeRegistro
//   Document No.           (6,     Code[20])   -> numeroDeDocumento
//   External Document No.  (56,    Code[35])   -> numeroDocumentoExterno
//   Source Type            (57,    Enum)       -> tipoDeOrigen
//   D365L CO Third No.     (66837, Code[35])   -> numeroDeTercero  (localización Colombia)
//   Amount                 (17,    Decimal)    -> importe
//   Columna "Alias" de la página               -> alias  (calculado, ver abajo)
//
// Añadido:
//   Entry No. (1) -> numeroMovimiento. Es el número de movimiento, único y
//     creciente: permite traer "solo lo nuevo" con un filtro como
//     numeroMovimiento gt 165945, sin depender de fechas.
//
// Sobre el "Alias":
//   No es un campo de la tabla 17. Lo pinta la extensión "D365LATAM AliasChange"
//   (pageextension 50221 "LyL GeneralLedgerPgExt") en una VARIABLE de página que
//   calcula al mostrar cada fila; no se guarda en ninguna tabla. Esa extensión no
//   publica su código ni permite depurarla, así que la fórmula se reconstruyó con
//   estas evidencias:
//   * "Alias" es la traducción al español de "Search Name". En sus listas de
//     ventas y compras, AliasChange oculta el Nombre y muestra el Alias junto al
//     N.º de cliente o proveedor.
//   * En la localización, el tercero de un proveedor o cliente es su propio N.º:
//     el diario hace "Third No." := "Account No.", y al registrar compras y
//     ventas usa Buy-from Vendor No. / Sell-to Customer No.
//   * Los movimientos de cierre (fecha U31/12) muestran Alias y no tienen N.º de
//     origen: la única referencia al tercero que tienen es "D365L CO Third No.".
//   Regla: Alias = "Search Name" del proveedor cuyo N.º es el tercero; si no hay
//   proveedor con ese N.º, el del cliente. Sin tercero, vacío.
//
// ¿Por qué no la API estándar microsoft/v2.0 generalLedgerEntries? No trae el
// documento externo, el tipo de origen, el tercero ni el alias, y separa el
// importe en debe y haber.
//
// Endpoint (entorno online):
//   .../api/bodhitri/contabilidad/v1.0/companies({id})/generalLedgerEntries
//
// Solo lectura: un movimiento contable no se crea, modifica ni borra por API.
// =============================================================================
page 50135 "BDT G/L Entry API"
{
    PageType = API;
    Caption = 'G/L Entries API';
    APIPublisher = 'bodhitri';
    APIGroup = 'contabilidad';
    APIVersion = 'v1.0';
    EntityName = 'generalLedgerEntry';
    EntitySetName = 'generalLedgerEntries';
    EntityCaption = 'General Ledger Entry';
    EntitySetCaption = 'General Ledger Entries';
    SourceTable = "G/L Entry";
    ODataKeyFields = SystemId;
    Extensible = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    // La tabla de movimientos crece sin parar (cientos de miles de filas):
    // leer de la réplica de solo lectura evita cargar la base principal del
    // ERP con las consultas del flujo.
    DataAccessIntent = ReadOnly;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                // Clave OData (SystemId): la que usa el conector de Business
                // Central para leer un registro concreto.
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                }
                field(numeroMovimiento; Rec."Entry No.")
                {
                    Caption = 'N.º mov.';
                }

                // --- Campos solicitados ----------------------------------------
                field(fechaDeRegistro; Rec."Posting Date")
                {
                    Caption = 'Fecha de registro';
                }
                field(numeroDeDocumento; Rec."Document No.")
                {
                    Caption = 'N.º documento';
                }
                field(numeroDocumentoExterno; Rec."External Document No.")
                {
                    Caption = 'N.º documento externo';
                }
                // Viaja como texto: ' ', 'Customer', 'Vendor', 'Bank Account',
                // 'Fixed Asset', 'IC Partner', 'Employee'.
                field(tipoDeOrigen; Rec."Source Type")
                {
                    Caption = 'Tipo de origen';
                }
                // Localización Colombia (D365LATAM), tabla ext. "D365L CO GLEntryExt".
                field(numeroDeTercero; Rec."D365L CO Third No.")
                {
                    Caption = 'Tercero';
                }
                field(importe; Rec.Amount)
                {
                    Caption = 'Importe';
                }
                // Calculado en OnAfterGetRecord, igual que la columna de la página.
                // Al no ser un campo de tabla, no se puede filtrar ni ordenar por
                // él en la consulta OData.
                field(alias; AliasTercero)
                {
                    Caption = 'Alias';
                }
            }
        }
    }

    var
        // Muchos movimientos comparten tercero: se guarda el alias ya resuelto
        // para no repetir la búsqueda en Proveedores y Clientes en cada fila.
        AliasPorTercero: Dictionary of [Code[35], Text[100]];
        AliasTercero: Text[100];

    trigger OnAfterGetRecord()
    begin
        AliasTercero := ObtenerAlias(Rec."D365L CO Third No.");
    end;

    /// <summary>
    /// Alias del tercero: "Search Name" del proveedor con ese N.º o, si no hay
    /// proveedor, el del cliente. Vacío si no hay tercero o no se encuentra.
    /// </summary>
    local procedure ObtenerAlias(Tercero: Code[35]): Text[100]
    var
        Vendor: Record Vendor;
        Customer: Record Customer;
        Alias: Text[100];
    begin
        if Tercero = '' then
            exit('');
        if AliasPorTercero.Get(Tercero, Alias) then
            exit(Alias);

        // El tercero admite 35 caracteres pero el N.º de proveedor y de cliente
        // solo 20: uno más largo no puede ser ninguno de los dos, y pasarlo a
        // Get() provocaría un error de desbordamiento.
        if StrLen(Tercero) <= MaxStrLen(Vendor."No.") then begin
            Vendor.SetLoadFields("Search Name");
            if Vendor.Get(Tercero) then
                Alias := Vendor."Search Name"
            else begin
                Customer.SetLoadFields("Search Name");
                if Customer.Get(Tercero) then
                    Alias := Customer."Search Name";
            end;
        end;

        AliasPorTercero.Add(Tercero, Alias);
        exit(Alias);
    end;
}
