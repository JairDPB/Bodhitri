// ============================================================================
//  Carga masiva de imágenes de productos desde un archivo .ZIP.
//
//  Uso: publica la app, en el ERP busca "Importar Imágenes de Productos (ZIP)",
//       marca (opcional) "Reemplazar imagen existente", marca (opcional)
//       "Crear productos que no existan" rellenando entonces los valores del
//       grupo "Valores para los productos nuevos", y pulsa "Importar ZIP...".
//  El .ZIP debe contener imágenes cuyo NOMBRE = N.º del producto
//  (p. ej. "1000.jpg", "ART-005.png"). Formatos: JPG/JPEG/PNG/BMP/GIF.
//
//  Todo ocurre en el servidor SaaS (UploadIntoStream + Data Compression),
//  sin rutas locales ni herramientas externas.
// ============================================================================
page 50101 "BDT Importar Img Items"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Tasks;
    Caption = 'Importar Imágenes de Productos (ZIP)';
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            group(Instrucciones)
            {
                Caption = 'Instrucciones';
                field(Info; InfoTxt)
                {
                    ApplicationArea = All;
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
            }
            group(Opciones)
            {
                Caption = 'Opciones';
                field(Reemplazar; ReplaceExisting)
                {
                    ApplicationArea = All;
                    Caption = 'Reemplazar imagen existente';
                    Editable = true;
                    ToolTip = 'Si está activo, borra la imagen actual del producto antes de importar la nueva. Si está inactivo, los productos que YA tienen imagen se omiten (no se les añade una segunda).';
                }
                field(CrearProductos; CrearFaltantes)
                {
                    ApplicationArea = All;
                    Caption = 'Crear productos que no existan';
                    Editable = true;
                    ToolTip = 'Si está activo, cuando el N.º del archivo no corresponda a ningún producto se crea el producto con los valores indicados abajo y se le asigna la imagen. Por defecto está desactivado: sólo se informan como no encontrados.';

                    trigger OnValidate()
                    begin
                        // Refresca la página para habilitar/deshabilitar el grupo de valores.
                        CurrPage.Update(false);
                    end;
                }
            }
            group(DatosCreacion)
            {
                Caption = 'Valores para los productos nuevos';
                Enabled = CrearFaltantes;

                field(GenProdPostGroup; NuevoGenProdPostGroup)
                {
                    ApplicationArea = All;
                    Caption = 'Grupo contable producto general';
                    Editable = true;
                    TableRelation = "Gen. Product Posting Group";
                    ToolTip = 'Grupo contable producto general con el que se crean los productos nuevos. Obligatorio: sin él el producto no se puede vender.';
                }
                field(VATProdPostGroup; NuevoVATProdPostGroup)
                {
                    ApplicationArea = All;
                    Caption = 'Grupo registro IVA producto';
                    Editable = true;
                    TableRelation = "VAT Product Posting Group";
                    ToolTip = 'Grupo de registro de IVA de producto con el que se crean los productos nuevos.';
                }
                field(InvPostGroup; NuevoInvPostGroup)
                {
                    ApplicationArea = All;
                    Caption = 'Grupo registro inventario';
                    Editable = true;
                    TableRelation = "Inventory Posting Group";
                    ToolTip = 'Grupo de registro de inventario con el que se crean los productos nuevos. Obligatorio para productos de tipo Inventario.';
                }
                field(BaseUOM; NuevoBaseUOM)
                {
                    ApplicationArea = All;
                    Caption = 'Unidad de medida base';
                    Editable = true;
                    TableRelation = "Unit of Measure";
                    ToolTip = 'Unidad de medida base con la que se crean los productos nuevos (p. ej. UND).';
                }
            }
            group(Resultado)
            {
                Caption = 'Resultado';
                field(Res; ResultText)
                {
                    ApplicationArea = All;
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Importar)
            {
                ApplicationArea = All;
                Caption = 'Importar ZIP...';
                Image = Import;
                ToolTip = 'Selecciona un .ZIP con las imágenes (nombre de archivo = N.º de producto).';

                trigger OnAction()
                begin
                    ImportFromZip();
                end;
            }
        }
    }

    var
        ReplaceExisting: Boolean;
        CrearFaltantes: Boolean;
        NuevoGenProdPostGroup: Code[20];
        NuevoVATProdPostGroup: Code[20];
        NuevoInvPostGroup: Code[20];
        NuevoBaseUOM: Code[10];
        ResultText: Text;
        // Contadores y listas del último proceso (globales para poder tratar cada
        // entrada en un procedimiento propio con salidas anticipadas: AL no tiene "continue").
        Importadas: Integer;
        Creados: Integer;
        NoEncontrados: Integer;
        YaTenianImagen: Integer;
        Duplicados: Integer;
        Omitidos: Integer;
        Fallidos: Integer;
        ListaNoEncontrados: Text;
        ListaFallidos: Text;
        Procesados: List of [Text];
        InfoTxt: Label 'Sube un archivo .ZIP cuyos archivos se llamen igual que el N.º del producto (ej. "1000.jpg", "ART-005.png"). Formatos: JPG/JPEG/PNG/BMP/GIF. Cada imagen se asigna al producto cuyo N.º coincide con el nombre del archivo (sin extensión).';
        FaltaDatoErr: Label 'Para crear productos que no existan hay que informar el campo "%1".', Comment = '%1 = título del campo que falta';
        NoExisteErr: Label 'El valor "%1" del campo "%2" no existe.', Comment = '%1 = código introducido, %2 = título del campo';
        GenProdCaptionTxt: Label 'Grupo contable producto general';
        VATProdCaptionTxt: Label 'Grupo registro IVA producto';
        InvPostCaptionTxt: Label 'Grupo registro inventario';
        BaseUOMCaptionTxt: Label 'Unidad de medida base';
        EntradaVaciaErr: Label 'La entrada "%1" del ZIP está vacía o no se pudo extraer.', Comment = '%1 = nombre de la entrada del ZIP';
        NoImportadaErr: Label 'El archivo "%1" no se pudo importar como imagen (formato no soportado o archivo dañado).', Comment = '%1 = nombre del archivo';
        ResumenTxt: Label 'Imágenes importadas: %1\Productos creados: %2\Productos no encontrados: %3  %4\Ya tenían imagen (no se reemplaza): %5\Duplicados en el ZIP: %6\Archivos omitidos (no imagen / nombre no válido): %7\Fallos: %8  %9', Comment = '%1..%9 = contadores y listas del proceso';

    local procedure ImportFromZip()
    var
        DataComp: Codeunit "Data Compression";
        ZipInStr: InStream;
        EntryList: List of [Text];
        EntryName: Text;
        FileName: Text;
    begin
        // Se comprueba ANTES de pedir el archivo: si faltan los grupos contables no
        // tiene sentido subir un ZIP de varios MB para fallar después.
        if CrearFaltantes then
            ComprobarDatosCreacion();

        if not UploadIntoStream('Selecciona el ZIP con las imágenes', '', 'Archivos ZIP (*.zip)|*.zip', FileName, ZipInStr) then
            exit;

        ReiniciarContadores();

        DataComp.OpenZipArchive(ZipInStr, false);
        DataComp.GetEntryList(EntryList);

        // Ninguna entrada puede abortar el lote: todo lo que puede fallar va dentro
        // de funciones [TryFunction] (ver ProcesarEntrada).
        foreach EntryName in EntryList do
            ProcesarEntrada(DataComp, EntryName);

        DataComp.CloseZipArchive();

        ResultText := StrSubstNo(
            ResumenTxt,
            Importadas, Creados, NoEncontrados, ListaNoEncontrados,
            YaTenianImagen, Duplicados, Omitidos, Fallidos, ListaFallidos);
        Message(ResultText);
    end;

    // Valida que los datos de creación estén completos y existan de verdad.
    // Motivo: un producto sin "Grupo contable producto general" (y sin "Grupo registro
    // inventario" cuando es de tipo Inventario) se inserta bien, pero SalesLine.CopyFromItem
    // hace TestField sobre ambos, así que el maestro quedaría inservible para vender.
    local procedure ComprobarDatosCreacion()
    var
        GenProdPostingGroup: Record "Gen. Product Posting Group";
        VATProductPostingGroup: Record "VAT Product Posting Group";
        InventoryPostingGroup: Record "Inventory Posting Group";
        UnitOfMeasure: Record "Unit of Measure";
    begin
        if NuevoGenProdPostGroup = '' then
            Error(FaltaDatoErr, GenProdCaptionTxt);
        if NuevoVATProdPostGroup = '' then
            Error(FaltaDatoErr, VATProdCaptionTxt);
        if NuevoInvPostGroup = '' then
            Error(FaltaDatoErr, InvPostCaptionTxt);
        if NuevoBaseUOM = '' then
            Error(FaltaDatoErr, BaseUOMCaptionTxt);

        if not GenProdPostingGroup.Get(NuevoGenProdPostGroup) then
            Error(NoExisteErr, NuevoGenProdPostGroup, GenProdCaptionTxt);
        if not VATProductPostingGroup.Get(NuevoVATProdPostGroup) then
            Error(NoExisteErr, NuevoVATProdPostGroup, VATProdCaptionTxt);
        if not InventoryPostingGroup.Get(NuevoInvPostGroup) then
            Error(NoExisteErr, NuevoInvPostGroup, InvPostCaptionTxt);
        if not UnitOfMeasure.Get(NuevoBaseUOM) then
            Error(NoExisteErr, NuevoBaseUOM, BaseUOMCaptionTxt);
    end;

    local procedure ReiniciarContadores()
    begin
        Importadas := 0;
        Creados := 0;
        NoEncontrados := 0;
        YaTenianImagen := 0;
        Duplicados := 0;
        Omitidos := 0;
        Fallidos := 0;
        ListaNoEncontrados := '';
        ListaFallidos := '';
        Clear(Procesados);
    end;

    // Trata UNA entrada del ZIP. Actualiza los contadores globales y nunca lanza Error:
    // así un archivo dañado o un producto problemático no tumba el resto del lote.
    local procedure ProcesarEntrada(var DataComp: Codeunit "Data Compression"; EntryName: Text)
    var
        Item: Record Item;
        NombreArchivo: Text;
        NombreSinExt: Text;
        ItemNo: Code[20];
    begin
        NombreArchivo := NombreDeArchivo(EntryName);
        if not IsImageEntry(NombreArchivo) then begin
            Omitidos += 1;
            exit;
        end;

        NombreSinExt := SinExtension(NombreArchivo);
        // Nunca truncar: un nombre de más de 20 caracteres recortado podría "acertar"
        // con OTRO producto distinto. Como hace la Base App, se descarta la entrada.
        if (NombreSinExt = '') or (StrLen(NombreSinExt) > MaxStrLen(Item."No.")) then begin
            Omitidos += 1;
            exit;
        end;
        ItemNo := CopyStr(NombreSinExt, 1, MaxStrLen(Item."No."));

        // Item.Picture es un MediaSet y ImportStream AÑADE a la colección: si el mismo
        // producto viniera dos veces en el ZIP acabaría con dos imágenes y el contador
        // mentiría. Se procesa sólo la primera aparición.
        if Procesados.Contains(ItemNo) then begin
            Duplicados += 1;
            exit;
        end;
        Procesados.Add(ItemNo);

        if not Item.Get(ItemNo) then begin
            if not CrearFaltantes then begin
                NoEncontrados += 1;
                if StrLen(ListaNoEncontrados) < 180 then
                    ListaNoEncontrados += ItemNo + ' ';
                exit;
            end;

            if not TryCrearProducto(ItemNo) then begin
                Fallidos += 1;
                AnotarFallo(ItemNo, GetLastErrorText());
                exit;
            end;
            Creados += 1;
            // Relectura: TryCrearProducto trabaja con su propia variable de registro.
            if not Item.Get(ItemNo) then begin
                Fallidos += 1;
                AnotarFallo(ItemNo, '');
                exit;
            end;
        end;

        // Con la opción de reemplazar desactivada hay que OMITIR, no acumular: sin este
        // control ImportStream añadiría una segunda imagen al producto en cada pasada.
        if Item.Picture.Count() > 0 then begin
            if not ReplaceExisting then begin
                YaTenianImagen += 1;
                exit;
            end;
            Clear(Item.Picture);
        end;

        if TryAsignarImagen(DataComp, EntryName, NombreArchivo, Item) then
            Importadas += 1
        else begin
            Fallidos += 1;
            AnotarFallo(ItemNo, GetLastErrorText());
        end;
    end;

    // Crea el producto con el código que viene en el nombre del archivo.
    //
    // OJO con el campo "No.": NO se puede usar Item.Validate("No.", ...). Su OnValidate
    // ejecuta NoSeries.TestManual(Configuración de inventario."Nos. producto"), que da error
    // si esa serie no admite números manuales y que además revienta con "registro no
    // encontrado" si el campo está en blanco o la serie no existe (TestManualInternal hace
    // un Get() sin guarda). Aquí el código ya lo impone el nombre del archivo, así que se
    // asigna DIRECTAMENTE: el OnInsert de Item sólo entra en la numeración automática
    // cuando "No." está vacío, y con "No." informado no exige ningún otro campo.
    [TryFunction]
    local procedure TryCrearProducto(ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        Item.Init();
        Item."No." := ItemNo;
        // No tenemos la descripción real aquí; dejarla vacía deja un maestro anónimo,
        // así que se repite el código y luego se puede corregir en la ficha.
        Item.Description := ItemNo;
        Item.Type := Item.Type::Inventory;

        // Estos tres no necesitan que el producto exista todavía.
        Item.Validate("Gen. Prod. Posting Group", NuevoGenProdPostGroup);
        // Después del anterior a propósito: al validar el grupo general se propone el IVA
        // por defecto de ese grupo, y aquí se impone el que ha elegido el usuario.
        Item.Validate("VAT Prod. Posting Group", NuevoVATProdPostGroup);
        // Su OnValidate hace TestField(Type, Type::Inventory), ya asignado arriba.
        Item.Validate("Inventory Posting Group", NuevoInvPostGroup);
        Item.Insert(true);

        // La unidad de medida base va DESPUÉS del Insert: su OnValidate crea el registro
        // "Item Unit of Measure" con Validate("Item No."), y esa relación de tabla exige
        // que el producto ya esté en la base de datos.
        Item.Validate("Base Unit of Measure", NuevoBaseUOM);
        Item.Modify(true);
    end;

    // Extrae la entrada del ZIP y la asigna al producto.
    // Se comprueba el Guid que devuelve ImportStream: devuelve un Guid nulo cuando la
    // importación falla (stream vacío, formato no soportado, archivo dañado); sin esta
    // comprobación se contaría como éxito un producto que se queda sin imagen.
    [TryFunction]
    local procedure TryAsignarImagen(var DataComp: Codeunit "Data Compression"; EntryName: Text; NombreArchivo: Text; var Item: Record Item)
    var
        TempBlob: Codeunit "Temp Blob";
        EntryInStr: InStream;
        EntryOutStr: OutStream;
    begin
        TempBlob.CreateOutStream(EntryOutStr);
        if DataComp.ExtractEntry(EntryName, EntryOutStr) <= 0 then
            Error(EntradaVaciaErr, EntryName);

        TempBlob.CreateInStream(EntryInStr);
        // Se pasa el nombre limpio (no la ruta dentro del ZIP) y el tipo MIME, que algunos
        // consumidores (API /pictures, informes Word/Excel, Power BI) necesitan para pintar.
        if IsNullGuid(Item.Picture.ImportStream(EntryInStr, NombreArchivo, TipoMime(NombreArchivo))) then
            Error(NoImportadaErr, NombreArchivo);

        // Modify() sin disparadores, como hace la Base App para esta misma operación:
        // el OnModify completo de Item ejecuta lógica de negocio ajena a la imagen que
        // podría hacer fallar la asignación.
        Item.Modify();
    end;

    local procedure AnotarFallo(ItemNo: Code[20]; Motivo: Text)
    begin
        if StrLen(ListaFallidos) > 250 then
            exit;
        if Motivo = '' then
            ListaFallidos += ItemNo + ' '
        else
            ListaFallidos += ItemNo + ' (' + CopyStr(Motivo, 1, 80) + ') ';
    end;

    local procedure IsImageEntry(EntryName: Text): Boolean
    var
        L: Text;
    begin
        L := EntryName.ToLower();
        exit(
            L.EndsWith('.jpg') or L.EndsWith('.jpeg') or L.EndsWith('.png') or
            L.EndsWith('.bmp') or L.EndsWith('.gif'));
    end;

    local procedure TipoMime(NombreArchivo: Text): Text
    var
        L: Text;
    begin
        L := NombreArchivo.ToLower();
        if L.EndsWith('.png') then
            exit('image/png');
        if L.EndsWith('.jpg') or L.EndsWith('.jpeg') then
            exit('image/jpeg');
        if L.EndsWith('.bmp') then
            exit('image/bmp');
        if L.EndsWith('.gif') then
            exit('image/gif');
        exit('');
    end;

    // Quita la ruta de subcarpetas del ZIP. Los ZIP estándar usan '/', pero se contempla
    // también '\' por si el archivo lo generó una herramienta que escribe separador Windows.
    local procedure NombreDeArchivo(EntryName: Text): Text
    var
        Name: Text;
        P: Integer;
    begin
        Name := EntryName;
        P := Name.LastIndexOf('/');
        if P > 0 then
            Name := CopyStr(Name, P + 1);
        P := Name.LastIndexOf('\');
        if P > 0 then
            Name := CopyStr(Name, P + 1);
        exit(DelChr(Name, '<>', ' '));
    end;

    local procedure SinExtension(NombreArchivo: Text): Text
    var
        Name: Text;
        P: Integer;
    begin
        Name := NombreArchivo;
        P := Name.LastIndexOf('.');
        if P > 1 then
            Name := CopyStr(Name, 1, P - 1);
        exit(DelChr(Name, '<>', ' '));            // recortar espacios sobrantes
    end;
}
