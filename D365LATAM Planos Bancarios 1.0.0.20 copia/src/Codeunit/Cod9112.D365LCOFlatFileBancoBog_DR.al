/// <summary>
/// Codeunit para generar plano para pagos a proveedores para el banco Banco Bogotá Colombia.
/// DelRio
/// </summary>
codeunit 99112 "D365L CO FlatFileBancoBog_DR"
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
        flatFileText: TextBuilder;
        flatFileText_lines: TextBuilder;
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
            ExcelBuffer.NewRow();
            ExcelBuffer.AddColumn('P', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);

            if GJL.FindFirst() then
                BankCode := GJL."Bal. Account No.";
            Bank.SetFilter("No.", BankCode);
            if Bank.FindFirst() then
                ExcelBuffer.AddColumn(Bank."Bank Account No.", false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
            ExcelBuffer.AddColumn(Format(System.Today(), 0, '<Day,2><Month,2><Year4>'), false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);

            Clear(GJL);
            GJL.SetFilter("Journal Batch Name", JBN);
            GJL.SetRange("Document Type", GJL."Document Type"::Payment);
            GJL.SetRange("Account Type", GJL."Account Type"::Vendor);
            GJL.SetRange("Bal. Account No.", BAN);
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

                                        //   ExcelBuffer.NewRow();
                                        flatFileText_lines.Append('R,');
                                        flatFileText_lines.Append(vendorBankAccount."Bank Account No." + ',');

                                        //ExcelBuffer.AddColumn('R', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                                        //   ExcelBuffer.AddColumn(vendorBankAccount."Bank Account No.", false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Ahorros" then
                                            flatFileText_lines.Append('Cuenta de Ahorros,');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Corriente" then
                                            flatFileText_lines.Append('Cuenta Corriente,');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Credito Rotativo" then
                                            flatFileText_lines.Append('Crédito Rotativo,');

                                        flatFileText_lines.Append(Format(tempAmount, 0, '<Integer>').Replace(',', '.') + ',');
                                        tempLength := Text.StrLen(vendorBankAccount."D365L CO Banks");
                                        if tempLength < 3 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 3, '0') + vendorBankAccount."D365L CO Banks" + ',');
                                        end else begin
                                            flatFileText_lines.Append(vendorBankAccount."D365L CO Banks" + ',');
                                        end;

                                        flatFileText_lines.Append(vendorData."VAT Registration No." + vendorData."D365L CO Verification Code" + ',');

                                        if vendorData."D365L CO DIAN Ident. Type" = '13' then
                                            nitLine := 'Cédula de Ciudadanía,';
                                        if vendorData."D365L CO DIAN Ident. Type" = '22' then
                                            nitLine := 'Cédula de Extranjería,';
                                        if vendorData."D365L CO DIAN Ident. Type" = '31' then
                                            nitLine := 'NIT Empresa,';
                                        if vendorData."D365L CO DIAN Ident. Type" = '12' then
                                            nitLine := 'Tarjeta de Identidad,';
                                        if vendorData."D365L CO DIAN Ident. Type" = '41' then
                                            nitLine := 'Pasaporte,';
                                        flatFileText_lines.Append(nitLine);

                                        nitLine := vendorData."Search Name";
                                        nitLine := DELCHR(nitLine, '=', DELCHR(nitLine, '=', txtCharsToKeep));
                                        flatFileText_lines.Append(nitLine.Trim() + ',');
                                        flatFileText_lines.Append('Activo,');
                                        // flatFileText_lines.Append('si,');
                                        flatFileText_lines.Append(GJL.Description.Trim() + ',');
                                        flatFileText_lines.Append(vendorData."E-Mail".Trim());
                                        flatFileText_lines.AppendLine();
                                        lineValidation := true;
                                    end;
                                end;
                            end;
                        end;
                    end;
                until GJL.Next() = 0;
            end;

            if lineValidation then begin
                fileName := 'FLATFILEBANCOBOG' + Format(System.Today(), 0, '<Year4><Month,2><Day,2>');
                flatFileText.Append('P,');
                flatFileText.Append(Bank."Bank Account No." + ',');
                flatFileText.Append(Format(System.Today(), 0, '<Day,2><Month,2><Year4>'));
                flatFileText.AppendLine();

                tmpBlob.CreateOutStream(OutStr);
                OutStr.WriteText(flatFileText.ToText() + flatFileText_lines.ToText());
                tmpBlob.CreateInStream(InStr);
                fileName := 'FLATFILEBANCOBOG' + Format(System.Today(), 0, '<Year4><Month,2><Day,2>') + '.txt';
                DownloadFromStream(InStr, '', '', '', fileName);
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