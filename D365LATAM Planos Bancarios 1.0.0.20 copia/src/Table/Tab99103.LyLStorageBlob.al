/// <summary>
/// No se esta utilizando
/// </summary>
table 99103 "D365L CO StorageBlob"
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Container"; Text[250])
        {
            DataClassification = CustomerContent;
            TableRelation = "D365L CO StorageContainer".Name;
            Editable = false;
        }

        field(2; "Name"; Text[250])
        {
            DataClassification = CustomerContent;
            Editable = false;
        }

        field(3; "Creation Time"; Text[50])
        {
            DataClassification = CustomerContent;
            Editable = false;
        }

        field(4; "Last Modified"; Text[50])
        {
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(5; "Lease Status"; Text[50])
        {
            DataClassification = CustomerContent;
            Editable = false;
        }

        field(6; "Lease State"; Text[50])
        {
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(7; "Content Type"; Text[50])
        {
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(8; "Content Length"; Integer)
        {
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(9; "Blob Type"; Text[50])
        {
            DataClassification = CustomerContent;
            Editable = false;
        }
    }

    keys
    {
        key(PK; Container, Name)
        {
            Clustered = true;
        }
    }

}