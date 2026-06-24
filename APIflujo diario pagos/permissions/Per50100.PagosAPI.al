// =============================================================================
// PermissionSet: BDT Pagos API (50100)
// -----------------------------------------------------------------------------
// Otorga a la credencial/usuario que consume la API (Power Automate) el acceso
// necesario para crear líneas de diario:
//   * Ejecutar la página API.
//   * Leer/insertar/modificar/borrar datos de "Gen. Journal Line" (81).
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
        page "BDT Gen. Journal Line API" = X;
}
