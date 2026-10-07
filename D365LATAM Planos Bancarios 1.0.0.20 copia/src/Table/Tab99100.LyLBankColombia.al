/// <summary>
/// Nueva tabla para el registro de bancos de Colombia
/// </summary>
table 99100 "D365L CO BankColombia"
{
    Caption = 'BankColombia';
    DataClassification = ToBeClassified;

    fields
    {
        field(99100; "Code"; Code[4])
        {
            Caption = 'Code';
            DataClassification = ToBeClassified;
        }
        field(99101; Name; Text[200])
        {
            Caption = 'Name';
            DataClassification = ToBeClassified;
        }
        field(99102; NationalAccount; Option)
        {
            Caption = 'NationalAccount';
            DataClassification = ToBeClassified;
            OptionMembers = "Si","No";
        }
    }
    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }
    }

}
