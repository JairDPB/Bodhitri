// ============================================================================
//  Carga masiva de imágenes de productos desde un archivo .ZIP.
//
//  Uso: publica la app, en el ERP busca "Importar Imágenes de Productos (ZIP)",
//       marca (opcional) "Reemplazar imagen existente" y pulsa "Importar ZIP...".
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
                    ToolTip = 'Si está activo, borra la imagen actual del producto antes de importar la nueva.';
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
        ResultText: Text;
        InfoTxt: Label 'Sube un archivo .ZIP cuyos archivos se llamen igual que el N.º del producto (ej. "1000.jpg", "ART-005.png"). Formatos: JPG/JPEG/PNG/BMP/GIF. Cada imagen se asigna al producto cuyo N.º coincide con el nombre del archivo (sin extensión).';

    local procedure ImportFromZip()
    var
        Item: Record Item;
        DataComp: Codeunit "Data Compression";
        TempBlob: Codeunit "Temp Blob";
        ZipInStr: InStream;
        EntryInStr: InStream;
        EntryOutStr: OutStream;
        EntryList: List of [Text];
        EntryName: Text;
        FileName: Text;
        ItemNo: Code[20];
        Imported: Integer;
        NotFound: Integer;
        Skipped: Integer;
        NotFoundList: Text;
    begin
        if not UploadIntoStream('Selecciona el ZIP con las imágenes', '', 'Archivos ZIP (*.zip)|*.zip', FileName, ZipInStr) then
            exit;

        DataComp.OpenZipArchive(ZipInStr, false);
        DataComp.GetEntryList(EntryList);

        foreach EntryName in EntryList do begin
            if not IsImageEntry(EntryName) then
                Skipped += 1
            else begin
                ItemNo := ItemNoFromEntry(EntryName);
                if not Item.Get(ItemNo) then begin
                    NotFound += 1;
                    if StrLen(NotFoundList) < 180 then
                        NotFoundList += ItemNo + ' ';
                end else begin
                    Clear(TempBlob);
                    TempBlob.CreateOutStream(EntryOutStr);
                    DataComp.ExtractEntry(EntryName, EntryOutStr);
                    TempBlob.CreateInStream(EntryInStr);
                    if ReplaceExisting then
                        Clear(Item.Picture);
                    Item.Picture.ImportStream(EntryInStr, EntryName);
                    Item.Modify(true);
                    Imported += 1;
                end;
            end;
        end;

        DataComp.CloseZipArchive();

        ResultText := StrSubstNo(
            'Importadas: %1\Productos no encontrados: %2  %3\Archivos omitidos (no imagen/carpeta): %4',
            Imported, NotFound, NotFoundList, Skipped);
        Message(ResultText);
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

    local procedure ItemNoFromEntry(EntryName: Text): Code[20]
    var
        Name: Text;
        P: Integer;
    begin
        Name := EntryName;
        P := Name.LastIndexOf('/');                 // quitar ruta de subcarpetas del zip
        if P > 0 then
            Name := CopyStr(Name, P + 1);
        P := Name.LastIndexOf('.');                 // quitar extensión
        if P > 1 then
            Name := CopyStr(Name, 1, P - 1);
        Name := DelChr(Name, '<>', ' ');            // recortar espacios
        exit(CopyStr(Name, 1, 20));
    end;
}
