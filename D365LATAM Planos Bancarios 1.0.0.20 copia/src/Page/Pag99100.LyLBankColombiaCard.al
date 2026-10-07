/// <summary>
/// Pagina para la creacion de banco de Colombia
/// </summary>
page 99100 "D365L CO BankColombiaCard"
{

    Caption = 'Bancos';
    PageType = Card;
    DataCaptionFields = Code;
    SourceTable = "D365L CO BankColombia";
    UsageCategory = Administration;
    ApplicationArea = All;

    layout
    {
        area(content)
        {
            group(General)
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
                    Caption = 'National Account', comment = 'ESP="Cuenta Nacional"';
                    ApplicationArea = All;
                }
            }
        }
    }
}
