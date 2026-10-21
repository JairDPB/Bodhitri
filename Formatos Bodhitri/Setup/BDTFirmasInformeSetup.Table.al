// ============================================================================
//  Configuración de las 3 firmas que aparecen al pie del informe financiero
//  (Report 25 "Account Schedule"). Tabla de un solo registro (setup).
// ============================================================================
table 50104 "BDT Firmas Informe Setup"
{
    Caption = 'Configuración de firmas del informe financiero';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10]) { Caption = 'Clave principal'; }

        field(10; "Firma 1 Nombre"; Text[100]) { Caption = 'Firma 1 - Nombre'; }
        field(11; "Firma 1 Cargo"; Text[100]) { Caption = 'Firma 1 - Cargo'; }
        field(12; "Firma 1 Identificacion"; Text[50]) { Caption = 'Firma 1 - C.C./T.P.'; }
        field(13; "Firma 1 Nota"; Text[100]) { Caption = 'Firma 1 - Nota'; }

        field(20; "Firma 2 Nombre"; Text[100]) { Caption = 'Firma 2 - Nombre'; }
        field(21; "Firma 2 Cargo"; Text[100]) { Caption = 'Firma 2 - Cargo'; }
        field(22; "Firma 2 Identificacion"; Text[50]) { Caption = 'Firma 2 - C.C./T.P.'; }
        field(23; "Firma 2 Nota"; Text[100]) { Caption = 'Firma 2 - Nota'; }

        field(30; "Firma 3 Nombre"; Text[100]) { Caption = 'Firma 3 - Nombre'; }
        field(31; "Firma 3 Cargo"; Text[100]) { Caption = 'Firma 3 - Cargo'; }
        field(32; "Firma 3 Identificacion"; Text[50]) { Caption = 'Firma 3 - C.C./T.P.'; }
        field(33; "Firma 3 Nota"; Text[100]) { Caption = 'Firma 3 - Nota'; }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
