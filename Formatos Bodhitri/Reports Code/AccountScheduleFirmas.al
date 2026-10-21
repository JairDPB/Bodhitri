// ============================================================================
//  Extensión del Report 25 "Account Schedule" (informe financiero) para:
//   - Inyectar el LOGO de la empresa (Company Information.Picture) en el dataset.
//   - Inyectar las 3 FIRMAS configurables (tabla BDT Firmas Informe Setup).
//  Las columnas se agregan al dataitem "Heading" (se ejecuta una sola vez).
//  El layout con logo + firmas se publica aparte (ver bloque rendering).
// ============================================================================
reportextension 50106 "BDT Account Schedule Firmas" extends "Account Schedule"
{
    dataset
    {
        add(Heading)
        {
            column(CompanyLogoBase64; CompanyLogoB64()) { }
            column(CompanyLogoMime; GetCompanyLogoMime()) { }

            column(Firma1Nombre; Firma(1, 1)) { }
            column(Firma1Cargo; Firma(1, 2)) { }
            column(Firma1Ident; Firma(1, 3)) { }
            column(Firma1Nota; Firma(1, 4)) { }

            column(Firma2Nombre; Firma(2, 1)) { }
            column(Firma2Cargo; Firma(2, 2)) { }
            column(Firma2Ident; Firma(2, 3)) { }
            column(Firma2Nota; Firma(2, 4)) { }

            column(Firma3Nombre; Firma(3, 1)) { }
            column(Firma3Cargo; Firma(3, 2)) { }
            column(Firma3Ident; Firma(3, 3)) { }
            column(Firma3Nota; Firma(3, 4)) { }
        }
    }

    rendering
    {
        // Layout nuevo = copia del horizontal de Microsoft + logo (PageHeader) + firmas (PageFooter).
        // Tras publicar, selecciónalo en "Diseños de informe" del informe 25.
        layout("AccountScheduleFirmasBDT")
        {
            Type = RDLC;
            LayoutFile = 'Reports/AccountScheduleFirmas.rdl';
            Caption = 'Informe financiero (logo + firmas) - Bodhitrí';
        }
    }

    var
        FirmasSetup: Record "BDT Firmas Informe Setup";
        FirmasLoaded: Boolean;
        LogoB64: Text;
        LogoCached: Boolean;

    local procedure LoadSetup()
    begin
        if FirmasLoaded then
            exit;
        if not FirmasSetup.Get() then
            Clear(FirmasSetup);
        FirmasLoaded := true;
    end;

    local procedure Firma(Slot: Integer; Part: Integer): Text
    begin
        LoadSetup();
        case Slot of
            1:
                exit(Pick(FirmasSetup."Firma 1 Nombre", FirmasSetup."Firma 1 Cargo", FirmasSetup."Firma 1 Identificacion", FirmasSetup."Firma 1 Nota", Part));
            2:
                exit(Pick(FirmasSetup."Firma 2 Nombre", FirmasSetup."Firma 2 Cargo", FirmasSetup."Firma 2 Identificacion", FirmasSetup."Firma 2 Nota", Part));
            3:
                exit(Pick(FirmasSetup."Firma 3 Nombre", FirmasSetup."Firma 3 Cargo", FirmasSetup."Firma 3 Identificacion", FirmasSetup."Firma 3 Nota", Part));
        end;
        exit('');
    end;

    local procedure Pick(ValNombre: Text; ValCargo: Text; ValIdent: Text; ValNota: Text; Part: Integer): Text
    begin
        case Part of
            1:
                exit(ValNombre);
            2:
                exit(ValCargo);
            3:
                exit(ValIdent);
            4:
                exit(ValNota);
        end;
        exit('');
    end;

    local procedure CompanyLogoB64(): Text
    begin
        if not LogoCached then begin
            LogoB64 := BuildCompanyLogoB64();
            LogoCached := true;
        end;
        exit(LogoB64);
    end;

    local procedure BuildCompanyLogoB64(): Text
    var
        CompanyInfo: Record "Company Information";
        Base64Convert: Codeunit "Base64 Convert";
        InStr: InStream;
    begin
        // Company Information."Picture" es un BLOB (Bitmap): se calcula y se lee directo.
        if not CompanyInfo.Get() then
            exit('');
        CompanyInfo.CalcFields(Picture);
        if not CompanyInfo.Picture.HasValue() then
            exit('');
        CompanyInfo.Picture.CreateInStream(InStr);
        exit(Base64Convert.ToBase64(InStr));
    end;

    local procedure GetCompanyLogoMime(): Text
    var
        B64: Text;
    begin
        // Detecta el formato por la firma Base64 (PNG/JPEG/BMP/GIF).
        B64 := CompanyLogoB64();
        if B64 = '' then
            exit('image/png');
        if B64.StartsWith('iVBOR') then
            exit('image/png');
        if B64.StartsWith('/9j/') then
            exit('image/jpeg');
        if B64.StartsWith('Qk') then
            exit('image/bmp');
        if B64.StartsWith('R0lGOD') then
            exit('image/gif');
        exit('image/png');
    end;
}
