// =============================================================================
// Page (API): BDT Item API (50101)
// -----------------------------------------------------------------------------
// Expone la tabla estándar "Item" (27) como entidad OData v4 para leer/actualizar
// desde Power Automate los campos que la API estándar "items" NO trae:
//   * LyL OrigenLP                 (extensión LyLVariantsExt, campo 80702)
//   * Tax Group Code               (estándar)
//   * Gen. Prod. Posting Group     (estándar)
//   * Inventory Posting Group      (estándar)
//   * Assembly Policy              (estándar, enum)
//   * D365L CO Sales Tax Group Code (extensión D365L CO) -> ver nota abajo.
//
// Los campos NO se crean (ya existen en la tabla Item); esta API solo los expone.
//
// Identificación del artículo:
//   * Clave OData estable: SystemId (campo 'id').
//   * 'number' (= "No.") y 'displayName' (= Description) para localizar/filtrar,
//     p. ej.  .../items?$filter=number eq '1000'
//
// Endpoint (entorno online):
//   .../api/bodhitri/maestros/v1.0/companies({id})/items
//
// NOTA D365L CO Sales Tax Group Code:
//   Ese campo pertenece a la extensión "D365L CO" (localización Colombia) y su
//   símbolo NO está en .alpackages, por eso está COMENTADO más abajo. Para
//   activarlo:
//     1) En VS Code: Ctrl+Shift+P -> "AL: Download Symbols" (con el sandbox de
//        launch.json) para traer el símbolo de D365L CO a .alpackages.
//     2) Agregar la dependencia de esa app en app.json (id/publisher/version que
//        verás en el símbolo descargado).
//     3) Descomentar el campo 'salesTaxGroupCode' de abajo (ajustar el nombre
//        exacto del campo si difiere).
// =============================================================================
page 50101 "BDT Item API"
{
    PageType = API;
    Caption = 'Items API';
    APIPublisher = 'bodhitri';
    APIGroup = 'maestros';
    APIVersion = 'v1.0';
    EntityName = 'item';
    EntitySetName = 'items';
    EntityCaption = 'Item';
    EntitySetCaption = 'Items';
    SourceTable = Item;
    DelayedInsert = true;
    ODataKeyFields = SystemId;
    Extensible = false;

    layout
    {
        area(Content)
        {
            repeater(Items)
            {
                // --- Identificación --------------------------------------------
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                    Editable = false;
                }
                field(numero; Rec."No.")
                {
                    Caption = 'No.';
                }
                field(descripcion; Rec.Description)
                {
                    Caption = 'Descripción';
                }
                field(tipo; Rec.Type)
                {
                    Caption = 'Tipo';
                }
                field(unidadMedidaBase; Rec."Base Unit of Measure")
                {
                    Caption = 'Unidad Medida Base';
                }
                field(codCategoria; Rec."Item Category Code")
                {
                    Caption = 'Cod. Categoría';
                }

                // --- Campos solicitados (nombres en español para Power Automate)
                field(origen; Rec."LyL OrigenLP")
                {
                    Caption = 'Origen';
                }
                field(codGrupoImpuestoCompra; Rec."Tax Group Code")
                {
                    Caption = 'Cod. Grupo Impuesto Compra';
                }
                field(grupoContableProdGen; Rec."Gen. Prod. Posting Group")
                {
                    Caption = 'Grupo Contable Prod. Gen.';
                }
                field(grupoRegistroInventario; Rec."Inventory Posting Group")
                {
                    Caption = 'Grupo Registro Inventario';
                }
                field(politicaEnsamblado; Rec."Assembly Policy")
                {
                    Caption = 'Política de Ensamblado';
                }

                // --- D365L CO Sales Tax Group Code (D365LATAM Colombia Loc.) ----
                // Dependencia declarada en app.json. Requiere "AL: Download Symbols"
                // para traer el símbolo de D365LATAM a .alpackages y poder compilar.
                field(codGrupoImpuestoVenta; Rec."D365L CO Sales Tax Group Code")
                {
                    Caption = 'Cod. Grupo Impuesto Venta';
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
}
