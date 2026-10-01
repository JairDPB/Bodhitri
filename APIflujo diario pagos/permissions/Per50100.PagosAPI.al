// =============================================================================
// PermissionSet: BDT Pagos API (50100)
// -----------------------------------------------------------------------------
// Otorga a la credencial/usuario que consume la API (Power Automate) el acceso
// necesario para crear líneas de diario:
//   * Ejecutar la página API.
//   * Leer/insertar/modificar/borrar datos de "Gen. Journal Line" (81).
//   * Leer/insertar/modificar cabeceras de compra "Purchase Header" (38) desde
//     la página API 50133 (facturas de compra del flujo de compras).
//   * Consumir numeración: la página 50131 llama a codeunit 310 "No. Series"
//     para autonumerar "External Document No.", lo que LEE "No. Series" (308) y
//     MODIFICA "Last No. Used" en "No. Series Line" (309).
//   * Leer el histórico de facturas de compra registradas desde la página API
//     50134 (sincronización con SharePoint): "Purch. Inv. Header" (122) y
//     "Purch. Inv. Line" (123), esta última porque el importe con IVA de la
//     cabecera es un FlowField que suma las líneas.
//
// Asígnalo al usuario de integración en BC (Usuarios > Conjuntos de permisos) o
// inclúyelo dentro de un rol mayor. Asignable = true para poder asignarlo solo.
// =============================================================================
permissionset 50100 "BDT Pagos API"
{
    Assignable = true;
    Caption = 'BDT Pagos API';

    Permissions =
        tabledata "Gen. Journal Line" = RIMD,
        tabledata Item = RM,
        // Cabeceras de compra (API 50133): leer/crear/modificar. Para permitir
        // DELETE desde el flujo, añadir D aquí y "Purchase Line" = RIMD (el
        // OnDelete de la cabecera borra sus líneas).
        tabledata "Purchase Header" = RIM,
        // Validar "Buy-from Vendor No." lee el maestro de proveedores, y la
        // autonumeración del "No." al crear lee la serie de "Compras y pagos".
        tabledata Vendor = R,
        tabledata "Purchases & Payables Setup" = R,
        // Numeración automática del documento externo (serie EGRESO).
        // Los permission sets Microsoft "No. Series - Read"/"- Admin" son
        // Access = Internal y Assignable = false, así que no se pueden incluir
        // desde esta extensión: se declaran las tablas directamente.
        tabledata "No. Series" = R,
        tabledata "No. Series Line" = RIMD,
        // Histórico de facturas de compra registradas (API 50134): solo lectura.
        // Sin "Purch. Inv. Line" el FlowField "Amount Including VAT" no se
        // puede calcular y la API devolvería error de permisos.
        tabledata "Purch. Inv. Header" = R,
        tabledata "Purch. Inv. Line" = R,
        page "BDT Gen. Journal Line API" = X,
        page "BDT Payment Journal Line API" = X,
        page "BDT Item API" = X,
        page "BDT Purchase Header API" = X,
        page "BDT Posted Purch. Inv. API" = X;
}
