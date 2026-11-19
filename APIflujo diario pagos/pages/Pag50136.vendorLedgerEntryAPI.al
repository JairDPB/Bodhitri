// =============================================================================
// Page (API): BDT Vendor Ledger Entry API (50136)
// -----------------------------------------------------------------------------
// Expone los movimientos de proveedor, tabla estándar "Vendor Ledger Entry" (25),
// como entidad OData v4 de SOLO LECTURA para armar el cuadro de pagos desde
// Power Automate.
//
// Para el cuadro de pagos sustituye a "BDT G/L Entry API" (50135): en
// Movs. proveedores hay UNA línea por documento (factura, nota crédito, pago)
// con su vencimiento y su saldo pendiente, en lugar de una línea por cuenta
// contable. La 50135 se mantiene para cualquier otro uso que tenga.
//
// Origen en BC:
//   Movs. proveedores (Vendor Ledger Entries, 29, List) -> Vendor Ledger Entry (25)
//
// Equivalencias con la API de movimientos contables (50135):
//   numeroMovimiento        <- Entry No.             (igual que en 50135)
//   fechaDeRegistro         <- Posting Date          (igual que en 50135)
//   numeroDeDocumento       <- Document No.          (igual que en 50135)
//   numeroDocumentoExterno  <- External Document No. (igual que en 50135)
//   tipoDeDocumento         <- Document Type
//       Sustituye a tipoDeOrigen: aquí todos los movimientos son de proveedor,
//       lo que distingue una fila de otra es si es factura, nota crédito o pago.
//   numeroDeTercero         <- Vendor No.
//       En la localización, el tercero de un proveedor es su propio N.º, así que
//       no hace falta leer "D365L CO Third No.".
//   importe                 <- Amount (FlowField)
//   alias                   <- "Search Name" del proveedor
//       Misma regla que en 50135, pero sin pasar por el tercero ni por
//       Clientes: el movimiento ya trae el N.º de proveedor.
//
// Añadidos para el cuadro de pagos:
//   nombreProveedor, fechaDocumento, fechaVencimiento, descripcion, divisa,
//   importePendiente, valorAPagar, abierto, retenido, formaDePago,
//   cuentaBancaria, banco, numeroDeCuenta, fechaUltimaModificacion
//
// Signos (los de BC): facturas en negativo; notas crédito y pagos en positivo.
// valorAPagar invierte el importe pendiente: factura = positivo (a pagar),
// nota crédito = negativo (descuenta).
//
// Sin DataAccessIntent = ReadOnly, a diferencia de 50135: el flujo lee el
// movimiento justo después de que se crea (y más adelante cuando cambia
// "abierto"), y la réplica de solo lectura puede ir unos segundos atrasada.
// Esta tabla es mucho más pequeña que G/L Entry, así que leer de la base
// principal no supone una carga relevante.
//
// Endpoint (entorno online):
//   .../api/bodhitri/contabilidad/v1.0/companies({id})/vendorLedgerEntries
//
// Solo lectura: un movimiento de proveedor no se crea, modifica ni borra por API.
// =============================================================================
page 50136 "BDT Vendor Ledger Entry API"
{
    PageType = API;
    Caption = 'Vendor Ledger Entries API';
    APIPublisher = 'bodhitri';
    APIGroup = 'contabilidad';
    APIVersion = 'v1.0';
    EntityName = 'vendorLedgerEntry';
    EntitySetName = 'vendorLedgerEntries';
    EntityCaption = 'Vendor Ledger Entry';
    EntitySetCaption = 'Vendor Ledger Entries';
    SourceTable = "Vendor Ledger Entry";
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
            repeater(Entries)
            {
                // Clave OData (SystemId): la que usa el conector de Business
                // Central para leer un registro concreto.
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                }
                // Único y creciente: sirve para buscar el registro en la lista
                // de SharePoint y para traer "solo lo nuevo"
                // (numeroMovimiento gt 170819).
                field(numeroMovimiento; Rec."Entry No.")
                {
                    Caption = 'N.º mov.';
                }

                // --- Equivalentes de la API de movimientos contables ---------
                field(fechaDeRegistro; Rec."Posting Date")
                {
                    Caption = 'Fecha de registro';
                }
                // N.º interno de BC: es el que se pasa en appliesToInvoiceNumber
                // al crear el pago en el diario, para que quede liquidado.
                field(numeroDeDocumento; Rec."Document No.")
                {
                    Caption = 'N.º documento';
                }
                // N.º de factura del proveedor (ej. FE3925): el que se muestra
                // en el cuadro de pagos.
                field(numeroDocumentoExterno; Rec."External Document No.")
                {
                    Caption = 'N.º documento externo';
                }
                // Viaja como texto con el nombre interno: ' ', 'Payment',
                // 'Invoice', 'Credit_x0020_Memo', 'Refund'... Verificar el valor
                // exacto en el historial de ejecución del flujo.
                field(tipoDeDocumento; Rec."Document Type")
                {
                    Caption = 'Tipo documento';
                }
                field(numeroDeTercero; Rec."Vendor No.")
                {
                    Caption = 'Tercero';
                }
                field(importe; Rec.Amount)
                {
                    Caption = 'Importe';
                }
                // Calculado en OnAfterGetRecord: no se puede filtrar ni ordenar
                // por él en la consulta OData.
                field(alias; AliasProveedor)
                {
                    Caption = 'Alias';
                }

                // --- Añadidos para el cuadro de pagos -------------------------
                field(nombreProveedor; Rec."Vendor Name")
                {
                    Caption = 'Nombre proveedor';
                }
                field(fechaDocumento; Rec."Document Date")
                {
                    Caption = 'Fecha documento';
                }
                field(fechaVencimiento; Rec."Due Date")
                {
                    Caption = 'Fecha vencimiento';
                }
                field(descripcion; Rec.Description)
                {
                    Caption = 'Descripción';
                }
                field(divisa; Rec."Currency Code")
                {
                    Caption = 'Divisa';
                }
                field(importePendiente; Rec."Remaining Amount")
                {
                    Caption = 'Importe pendiente';
                }
                // Importe pendiente con el signo invertido, listo para el cuadro.
                field(valorAPagar; ValorAPagar)
                {
                    Caption = 'Valor a pagar';
                }
                // Pasa a false cuando el documento queda totalmente liquidado.
                field(abierto; Rec.Open)
                {
                    Caption = 'Abierto';
                }
                // Columna "Esperar" de la página: si tiene valor, la factura
                // está retenida y no debería pagarse.
                field(retenido; Rec."On Hold")
                {
                    Caption = 'Esperar (retenido)';
                }
                field(formaDePago; Rec."Payment Method Code")
                {
                    Caption = 'Forma de pago';
                }
                // Cuenta indicada en el movimiento ("Cta. bancaria destinatario");
                // si está vacía, la cuenta preferida de la ficha del proveedor.
                field(cuentaBancaria; CuentaBancaria)
                {
                    Caption = 'Cuenta bancaria';
                }
                field(banco; Banco)
                {
                    Caption = 'Banco';
                }
                field(numeroDeCuenta; NumeroDeCuenta)
                {
                    Caption = 'N.º de cuenta';
                }
                // TipoCuenta (ahorros/corriente): no es un campo estándar de
                // "Vendor Bank Account". Si la localización lo agrega, ubicarlo
                // con Inspección de la página en la ficha de la cuenta bancaria
                // del proveedor y exponerlo igual que banco y numeroDeCuenta.
                field(fechaUltimaModificacion; Rec.SystemModifiedAt)
                {
                    Caption = 'Última modificación';
                }
            }
        }
    }

    var
        // Muchos movimientos son del mismo proveedor y la misma cuenta: se
        // guardan los datos ya resueltos para no repetir búsquedas en cada fila.
        AliasPorProveedor: Dictionary of [Code[20], Text[100]];
        CuentaPreferidaPorProveedor: Dictionary of [Code[20], Code[20]];
        BancoPorCuenta: Dictionary of [Text, Text[100]];
        NumeroCuentaPorCuenta: Dictionary of [Text, Text[30]];
        AliasProveedor: Text[100];
        CuentaBancaria: Code[20];
        Banco: Text[100];
        NumeroDeCuenta: Text[30];
        ValorAPagar: Decimal;

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields(Amount, "Remaining Amount");
        ValorAPagar := -Rec."Remaining Amount";

        CargarDatosProveedor(Rec."Vendor No.");
        AliasProveedor := AliasPorProveedor.Get(Rec."Vendor No.");

        CuentaBancaria := Rec."Recipient Bank Account";
        if CuentaBancaria = '' then
            CuentaBancaria := CuentaPreferidaPorProveedor.Get(Rec."Vendor No.");
        ObtenerDatosCuenta(Rec."Vendor No.", CuentaBancaria);
    end;

    /// <summary>
    /// Guarda en caché el alias ("Search Name") y la cuenta bancaria preferida
    /// del proveedor. Vacíos si el proveedor no existe.
    /// </summary>
    local procedure CargarDatosProveedor(NumeroProveedor: Code[20])
    var
        Vendor: Record Vendor;
        Alias: Text[100];
        CuentaPreferida: Code[20];
    begin
        if AliasPorProveedor.ContainsKey(NumeroProveedor) then
            exit;

        Vendor.SetLoadFields("Search Name", "Preferred Bank Account Code");
        if Vendor.Get(NumeroProveedor) then begin
            Alias := Vendor."Search Name";
            CuentaPreferida := Vendor."Preferred Bank Account Code";
        end;

        AliasPorProveedor.Add(NumeroProveedor, Alias);
        CuentaPreferidaPorProveedor.Add(NumeroProveedor, CuentaPreferida);
    end;

    /// <summary>
    /// Banco y N.º de cuenta de la cuenta bancaria del proveedor.
    /// Vacíos si no hay cuenta o no se encuentra.
    /// </summary>
    local procedure ObtenerDatosCuenta(NumeroProveedor: Code[20]; CodigoCuenta: Code[20])
    var
        VendorBankAccount: Record "Vendor Bank Account";
        Clave: Text;
        NombreBanco: Text[100];
        NumeroCuenta: Text[30];
    begin
        Banco := '';
        NumeroDeCuenta := '';
        if CodigoCuenta = '' then
            exit;

        Clave := NumeroProveedor + '|' + CodigoCuenta;
        if not BancoPorCuenta.ContainsKey(Clave) then begin
            VendorBankAccount.SetLoadFields(Name, "Bank Account No.");
            if VendorBankAccount.Get(NumeroProveedor, CodigoCuenta) then begin
                NombreBanco := VendorBankAccount.Name;
                NumeroCuenta := VendorBankAccount."Bank Account No.";
            end;
            BancoPorCuenta.Add(Clave, NombreBanco);
            NumeroCuentaPorCuenta.Add(Clave, NumeroCuenta);
        end;

        Banco := BancoPorCuenta.Get(Clave);
        NumeroDeCuenta := NumeroCuentaPorCuenta.Get(Clave);
    end;
}
