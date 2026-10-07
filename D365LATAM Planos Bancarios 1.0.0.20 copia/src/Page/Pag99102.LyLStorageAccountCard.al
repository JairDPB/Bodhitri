/// <summary>
/// Pagina para el registro de configuracion de cuenta de almacenamiento en Azure
/// </summary>
page 99102 "D365L CO StorageAccountCard"
{
    PageType = Card;
    SourceTable = "D365L CO StorageAccount";
    Caption = 'Cuenta Almacenamiento-Setup Planos Bancarios';
    ApplicationArea = All;
    UsageCategory = ReportsAndAnalysis;

    layout
    {
        area(content)
        {
            group(General)
            {
                field("Account Name"; Rec."Account Name")
                {
                    ApplicationArea = All;
                }
                field(Container; Rec.Container)
                {
                    ApplicationArea = All;
                }
                field("Account Url"; Rec."Account Url")
                {
                    ApplicationArea = All;
                }
                field("SaS Token"; Rec."SaS Token")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}