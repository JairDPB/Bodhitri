/// <summary>
/// Pagina tipo lista para mostrar los bancos de Colombia
/// </summary>
page 99101 "D365L CO BankColombiaList"
{

    ApplicationArea = All;
    Caption = 'Bancos Colombia';
    PageType = List;
    SourceTable = "D365L CO BankColombia";
    UsageCategory = Lists;
    CardPageId = "D365L CO BankColombiaCard";
    RefreshOnActivate = true;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("Code"; Rec.Code)
                {
                    Caption = 'Code', comment = 'ESP="Código"';
                    ApplicationArea = All;
                }
                field(Name; Rec.Name)
                {
                    Caption = 'Name', comment = 'ESP="Nombre"';
                    ApplicationArea = All;
                }
                field(NationalAccount; Rec.NationalAccount)
                {
                    Caption = 'Account National', comment = 'ESP="Cuenta Nacional"';
                    ApplicationArea = All;
                }
            }
        }
    }

}
