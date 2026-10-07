/// <summary>
/// Extension de pagina de registro de banco para incluir campos adicionales para la generacion de planos bancarios
/// </summary>
pageextension 99102 "D365L CO BankAccountCard" extends "Bank Account Card"
{
    layout
    {
        addlast(General)
        {
            field("D365L CO AccountType"; Rec."D365L CO AccountType")
            {
                ApplicationArea = all;
                Caption = 'Tipo de Cuenta';
            }
            field("D365L CO BankCode"; Rec."D365L CO BankCode")
            {
                ApplicationArea = all;
                Caption = 'Codigo Banco';
            }
            field("D365L CO Encrypt pgp"; Rec."D365L CO Encrypt pgp")
            {
                ApplicationArea = all;
                Caption = 'Encriptado';
            }

        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
}