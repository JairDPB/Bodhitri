/// <summary>
/// Tabla para el registro de configuracion de cuenta de almacenamiento en Azure
/// </summary>
table 99101 "D365L CO StorageAccount"
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Account Name"; Text[50])
        {
            DataClassification = CustomerContent;
        }

        field(2; "Account Url"; Text[250])
        {
            DataClassification = CustomerContent;
            ExtendedDatatype = URL;
        }

        field(3; "SaS Token"; Text[250])
        {
            DataClassification = CustomerContent;
            //ExtendedDatatype = Masked;
        }
        field(4; Container; Text[30])
        {
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Account Name")
        {
            Clustered = true;
        }
    }

}