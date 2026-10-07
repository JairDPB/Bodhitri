/// <summary>
/// Codeunit para generacion de plano de pagos a proveedores para el banco Santander Colombia.
/// </summary>
codeunit 99111 "D365L CO FlatFileSantander_SY"
{
    TableNo = "Gen. Journal Line";
    trigger OnRun()
    begin
        GenerateFile(Rec."Journal Batch Name", Rec."Bal. Account No.");
    end;

    local procedure GenerateFile(JBN: Code[10]; BAN: Code[20])
    var
        vendorData: Record Vendor;
        companyData: Record "Company Information";
        InStr: InStream;
        OutStr: OutStream;
        tmpBlob: Codeunit "Temp Blob";
        fileName: Text;
        tempLength: Integer;
        tempText: Text;
        totalCredit: Decimal;
        GJL: Record "Gen. Journal Line";
        tempAmount: Decimal;
        GJL_list: List of [Code[20]];
        Bank: Record "Bank Account";
        BankCode: Code[20];
        vendorBankAccount: Record "Vendor Bank Account";
        amountText: text;
        nitLine: Text;
        lineValidation: Boolean;
        totallineCount: Text;
        txtCharsToKeep: Text;
        DVvendor: Text;

        ExcelBuffer: Record "Excel Buffer" temporary; // Tabla temporal
        TempBlob: Codeunit "Temp Blob";
        FileManagement: Codeunit "File Management";
        OutStream: OutStream;
    begin
        txtCharsToKeep := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 ';
        companyData.Get();
        lineValidation := false;
        GJL.SetFilter("Journal Batch Name", JBN);
        GJL.SetRange("Document Type", GJL."Document Type"::Payment);
        GJL.SetRange("Account Type", GJL."Account Type"::Vendor);
        GJL.SetRange("Bal. Account No.", BAN);

        // Limpiar el buffer
        ExcelBuffer.DeleteAll();
        ExcelBuffer.Reset();

        if (GJL.Count() > 0) and (companyData."VAT Registration No." <> '') then begin
            // LINES
            totalCredit := 0;
            if GJL.FindSet() then begin
                repeat
                    if (GJL_list.Count() = 0) or (GJL_list.IndexOf(GJL."Bill-to/Pay-to No.") = 0) then begin
                        if (GJL."Bill-to/Pay-to No." <> '') and (GJL."Bal. Account No." <> '') and (GJL."Recipient Bank Account" <> '') then begin
                            GJL_list.Add(GJL."Bill-to/Pay-to No.");
                            vendorData.SetFilter("No.", GJL."Bill-to/Pay-to No.");
                            if (vendorData.FindFirst()) and (vendorData."VAT Registration No." <> '') and (vendorData.Name <> '') then begin
                                vendorBankAccount.SetFilter(Code, GJL."Recipient Bank Account");
                                vendorBankAccount.SetFilter("Vendor No.", vendorData."No.");
                                vendorBankAccount.FindFirst();
                                if Text.StrLen(vendorBankAccount."Bank Account No.") > 0 then begin
                                    tempAmount := calculateAmount(GJL."Bill-to/Pay-to No.", JBN);
                                    if tempAmount > 0 then begin
                                        totalCredit += tempAmount;
                                        BankCode := GJL."Bal. Account No.";

                                        ExcelBuffer.NewRow();

                                        nitLine := vendorData."Search Name";
                                        nitLine := DELCHR(nitLine, '=', DELCHR(nitLine, '=', txtCharsToKeep));
                                        ExcelBuffer.AddColumn(nitLine, false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);

                                        if vendorData."D365L CO DIAN Ident. Type" = '13' then
                                            nitLine := '01';
                                        if vendorData."D365L CO DIAN Ident. Type" = '21' then
                                            nitLine := '02';
                                        if vendorData."D365L CO DIAN Ident. Type" = '31' then
                                            nitLine := '03';
                                        if vendorData."D365L CO DIAN Ident. Type" = '12' then
                                            nitLine := '04';
                                        if vendorData."D365L CO DIAN Ident. Type" = '41' then
                                            nitLine := '05';
                                        ExcelBuffer.AddColumn(nitLine, false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                                        ExcelBuffer.AddColumn(vendorData."VAT Registration No.", false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);

                                        tempLength := Text.StrLen(vendorBankAccount."D365L CO Banks");
                                        if tempLength < 4 then begin
                                            nitLine := GetFill(tempLength, 4, '0') + vendorBankAccount."D365L CO Banks";
                                        end else begin
                                            nitLine := vendorBankAccount."D365L CO Banks";
                                        end;
                                        ExcelBuffer.AddColumn(nitLine, false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);

                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Ahorros" then
                                            ExcelBuffer.AddColumn('AHORROS', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Corriente" then
                                            ExcelBuffer.AddColumn('CORRIENTE', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                                        ExcelBuffer.AddColumn(vendorBankAccount."Bank Account No.", false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                                        ExcelBuffer.AddColumn(tempAmount, false, '', false, false, false, '', ExcelBuffer."Cell Type"::Number);
                                        ExcelBuffer.AddColumn('SI', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                                        ExcelBuffer.AddColumn(GJL.Description, false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                                        lineValidation := true;
                                    end;
                                end;
                            end;
                        end;
                    end;
                until GJL.Next() = 0;
            end;

            if lineValidation then begin
                fileName := 'FLATFILESANTANDER' + Format(System.Today(), 0, '<Year4><Month,2><Day,2>');
                // Crear el archivo Excel
                ExcelBuffer.CreateNewBook('FileSantander');
                ExcelBuffer.WriteSheet('FileSantander', CompanyName, UserId);
                ExcelBuffer.CloseBook();
                ExcelBuffer.SetFriendlyFilename(fileName);
                ExcelBuffer.OpenExcel();
            end else begin
                Message('No se generaron lineas en para el archivo.');
            end;
        end else begin
            if companyData."VAT Registration No." = '' then
                Message('Error. la compañia no tiene indentificado el NIT');
            if GJL.Count() = 0 then
                Message('No existen lineas de con pagos a proveedores');
        end;
    end;

    local procedure dataValidation()
    var
        myInt: Integer;
    begin

    end;

    local procedure FillBlank(Quantity: Integer): Text
    var
        relleno: Text;
        x: Integer;
    begin
        FOR x := 1 to Quantity DO BEGIN
            relleno += ' ';
        END;
        exit(relleno);
    end;

    local procedure GetFill(textLeng: Integer; maxlen: Integer; caracter: Text): Text
    var
        len: Integer;
        relleno: Text;
        x: Integer;
    begin
        len := maxlen - textLeng;
        relleno := '';
        FOR x := 1 to len DO BEGIN
            relleno += caracter;
        END;
        exit(relleno);
    end;

    local procedure calculateAmount(VendorCode: Code[20]; JBN: Code[20]): Decimal
    var
        GJL_temp: Record "Gen. Journal Line";
    begin
        GJL_temp.SetFilter("Bill-to/Pay-to No.", VendorCode);
        GJL_temp.SetFilter("Journal Batch Name", JBN);
        GJL_temp.CalcSums(Amount);
        exit(GJL_temp.Amount);
    end;
}