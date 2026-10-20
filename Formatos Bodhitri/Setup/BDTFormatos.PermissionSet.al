// ============================================================================
//  Permission set de la extensión. Requerido en per-tenant extensions (PTE):
//  toda tabla propia debe estar cubierta por un permission set (error PTE0004).
//  Nombre (identificador) <= 20 caracteres.
// ============================================================================
permissionset 50107 "BDT Formatos"
{
    Assignable = true;
    Caption = 'Formatos Bodhitrí';

    Permissions =
        tabledata "BDT Firmas Informe Setup" = RIMD,
        page "BDT Firmas Informe Setup" = X,
        page "BDT Buscar App Objeto" = X,
        page "BDT Importar Img Items" = X,
        report "BDT Compras Pend Recibir" = X,
        report "BDT Compras Pend Facturar" = X;
}
