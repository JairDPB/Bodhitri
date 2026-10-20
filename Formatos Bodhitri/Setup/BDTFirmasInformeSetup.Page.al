// ============================================================================
//  Página de configuración de las 3 firmas del informe financiero.
//  Búscala en el ERP como "Configuración de firmas del informe financiero".
// ============================================================================
page 50105 "BDT Firmas Informe Setup"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "BDT Firmas Informe Setup";
    Caption = 'Configuración de firmas del informe financiero BH';
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Firma1)
            {
                Caption = 'Firma RL';
                field("Firma 1 Nombre"; Rec."Firma 1 Nombre") { ApplicationArea = All; ToolTip = 'Nombre de quien firma (ej. Representante Legal).'; }
                field("Firma 1 Cargo"; Rec."Firma 1 Cargo") { ApplicationArea = All; ToolTip = 'Cargo (ej. Representante Legal).'; }
                field("Firma 1 Identificacion"; Rec."Firma 1 Identificacion") { ApplicationArea = All; ToolTip = 'C.C. o T.P. (ej. C.C. 80.105.654).'; }
                field("Firma 1 Nota"; Rec."Firma 1 Nota") { ApplicationArea = All; ToolTip = 'Línea adicional opcional (ej. Designado por: ...).'; }
            }
            group(Firma2)
            {
                Caption = 'Firma RF';
                field("Firma 2 Nombre"; Rec."Firma 2 Nombre") { ApplicationArea = All; }
                field("Firma 2 Cargo"; Rec."Firma 2 Cargo") { ApplicationArea = All; }
                field("Firma 2 Identificacion"; Rec."Firma 2 Identificacion") { ApplicationArea = All; }
                field("Firma 2 Nota"; Rec."Firma 2 Nota") { ApplicationArea = All; }
            }
            group(Firma3)
            {
                Caption = 'Firma CP';
                field("Firma 3 Nombre"; Rec."Firma 3 Nombre") { ApplicationArea = All; }
                field("Firma 3 Cargo"; Rec."Firma 3 Cargo") { ApplicationArea = All; }
                field("Firma 3 Identificacion"; Rec."Firma 3 Identificacion") { ApplicationArea = All; }
                field("Firma 3 Nota"; Rec."Firma 3 Nota") { ApplicationArea = All; }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec."Primary Key" := '';
            Rec.Insert();
        end;
    end;
}
