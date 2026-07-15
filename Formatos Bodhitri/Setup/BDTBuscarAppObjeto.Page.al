// ============================================================================
//  Utilidad Bodhitrí: localizar QUÉ extensión (app) publica un objeto.
//  Uso: publica la app, en el ERP busca en "Dígame" -> "Buscar App de Objeto",
//       escribe el ID (viene 50201 por defecto) y pulsa "Buscar extensión".
//  Mapea Object ID -> App ID (AllObjWithCaption) -> Nombre/Editor (NAV App Installed App).
//  Si VS Code marca los namespaces, usa Ctrl+. para agregar los "using".
// ============================================================================
page 50149 "BDT Buscar App Objeto"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Buscar App de Objeto';
    Editable = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            group(Filtro)
            {
                Caption = 'Objeto a localizar';
                field(ObjectIdToFind; ObjectIdToFind)
                {
                    Caption = 'ID de objeto';
                    ApplicationArea = All;
                    ToolTip = 'ID del objeto a localizar (por ejemplo 50201, el reporte de cotización).';
                }
            }
            group(Resultado)
            {
                Caption = 'Resultado';
                field(ResultText; ResultText)
                {
                    Caption = 'Extensión(es) encontradas';
                    ApplicationArea = All;
                    Editable = false;
                    MultiLine = true;
                    ShowCaption = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Buscar)
            {
                Caption = 'Buscar extensión';
                ApplicationArea = All;
                Image = Find;
                ToolTip = 'Busca en todas las apps instaladas cuál publica el objeto indicado.';

                trigger OnAction()
                begin
                    ResultText := FindOwner(ObjectIdToFind);
                    Message(ResultText);
                end;
            }
        }
    }

    var
        ObjectIdToFind: Integer;
        ResultText: Text;

    trigger OnOpenPage()
    begin
        ObjectIdToFind := 50201;
    end;

    local procedure FindOwner(ObjId: Integer): Text
    var
        AllObj: Record AllObjWithCaption;
        InstalledApp: Record "NAV App Installed App";
        Res: Text;
    begin
        AllObj.SetRange("Object ID", ObjId);
        if not AllObj.FindSet() then
            exit(StrSubstNo('No existe ningún objeto con ID %1 en este entorno.', ObjId));

        repeat
            Res += StrSubstNo('%1 %2  -  "%3"\', Format(AllObj."Object Type"), ObjId, AllObj."Object Name");
            if IsNullGuid(AllObj."App ID") then
                Res += '   App: (objeto base de Microsoft / sin app)\\'
            else begin
                InstalledApp.Reset();
                InstalledApp.SetRange("App ID", AllObj."App ID");
                if InstalledApp.FindFirst() then
                    Res += StrSubstNo('   Extensión: %1\   Editor: %2\   Versión: %3.%4.%5.%6\   Publicada como: %7\   App ID: %8\\',
                        InstalledApp.Name, InstalledApp.Publisher,
                        InstalledApp."Version Major", InstalledApp."Version Minor",
                        InstalledApp."Version Build", InstalledApp."Version Revision",
                        Format(InstalledApp."Published As"), AllObj."App ID")
                else
                    Res += StrSubstNo('   App ID: %1 (no encontrada en apps instaladas)\\', AllObj."App ID");
            end;
        until AllObj.Next() = 0;

        exit(Res);
    end;
}
