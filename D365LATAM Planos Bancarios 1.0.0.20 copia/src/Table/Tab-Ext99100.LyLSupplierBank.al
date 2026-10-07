/// <summary>
/// Extension de tabla Banco Proveedor para incluir nuevos campos para la generacion de planos bancarios
/// </summary>
tableextension 99100 "D365L CO Supplier Bank" extends "Vendor Bank Account"
{
    fields
    {
        field(99100; "D365L CO AccountType"; Option)
        {
            Caption = 'AccountType';
            DataClassification = ToBeClassified;
            OptionMembers = "Cuenta Ahorros","Cuenta Corriente","Credito Rotativo","Tarjeta Prepago Maestro";
        }
        field(99101; "D365L CO Banks"; Code[4])
        {
            Caption = 'Banks';
            DataClassification = ToBeClassified;
            TableRelation = "D365L CO BankColombia".Code;
        }
        field(99103; LyLThirdPayment; Boolean)
        {
            DataClassification = ToBeClassified;
        }
        field(99104; "D365L CO ThirdNit"; Code[20])
        {
            DataClassification = ToBeClassified;
        }
        field(99105; "D365L CO ThirdDV"; Integer)
        {
            DataClassification = ToBeClassified;
        }
        field(99106; "D365L CO ThirdName"; Text[200])
        {
            DataClassification = ToBeClassified;
        }
    }
}
