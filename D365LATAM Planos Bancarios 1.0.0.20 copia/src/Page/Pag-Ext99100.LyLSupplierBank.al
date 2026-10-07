/// <summary>
/// Extension de pagina de registro de banco de proveedor para incluir campos adicionales para la generacion de planos bancarios
/// </summary>
pageextension 99100 "D365L CO Supplier Bank" extends "Vendor Bank Account Card"
{
    layout
    {
        addlast(General)
        {
            field("D365L CO AccountType"; Rec."D365L CO AccountType")
            {
                Caption = 'Account Type', comment = 'ESP="Tipo de Cuenta"';
                ApplicationArea = All;
            }

            field("D365L CO Banks"; Rec."D365L CO Banks")
            {
                Caption = 'Bank', comment = 'ESP="Banco"';
                ApplicationArea = All;
            }
            field("D365L CO ThirdPayment"; Rec.LyLThirdPayment)
            {
                Caption = 'Pago a Tercero';
                ApplicationArea = all;
            }
            field("D365L CO ThirdNit"; Rec."D365L CO ThirdNit")
            {
                Caption = 'Tercero Nit';
                ApplicationArea = all;
            }
            field("D365L CO ThirdDV"; Rec."D365L CO ThirdDV")
            {
                Caption = 'Tercero Digito Verificación';
                ApplicationArea = all;
            }
            field("D365L CO ThirdName"; Rec."D365L CO ThirdName")
            {
                Caption = 'Tercero Nombre';
                ApplicationArea = all;
            }
        }
    }
}