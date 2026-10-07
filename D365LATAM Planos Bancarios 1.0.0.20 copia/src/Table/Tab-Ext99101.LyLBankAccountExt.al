/// <summary>
/// Extension de tabla de Banco para incluir nuevos campos para la generacion de planos bancarios
/// </summary>
tableextension 99101 "D365L CO BankAccountExt" extends "Bank Account"
{
    fields
    {
        field(99100; "D365L CO AccountType"; Option)
        {
            Caption = 'AccountType';
            DataClassification = ToBeClassified;
            OptionMembers = "Cuenta Ahorros","Cuenta Corriente","Credito Rotativo";
        }
        field(99101; "D365L CO BankCode"; Code[20])
        {
            Caption = 'BankCode';
            DataClassification = ToBeClassified;
        }
        field(99102; "D365L CO Encrypt pgp"; Boolean)
        {
            DataClassification = ToBeClassified;
        }
    }
}
