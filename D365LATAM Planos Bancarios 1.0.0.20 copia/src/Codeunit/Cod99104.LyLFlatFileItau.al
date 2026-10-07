/// <summary>
/// Codeunit para generar archivo plano de pagos a proveedores banco ITAU
/// </summary>
codeunit 99104 "D365L CO FlatFileItau"
{
    TableNo = "Gen. Journal Line";
    trigger OnRun()
    begin
        GenerateFile(Rec."Journal Batch Name", Rec."Bal. Account No.");
    end;

    local procedure GenerateFile(JBN: Code[10]; BAN: Code[20])
    var
        vendorData: Record Vendor;
        flatFileText: TextBuilder;
        flatFileText_lines: TextBuilder;
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
        vendorName: Text;
        lineValidation: Boolean;
        totallineCount: Text;
        txtCharsToKeep: Text;
        vendorPhone: Text;
        seq: Integer;
    begin
        seq := 0;
        txtCharsToKeep := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 ';
        // crear un metodo de validacion antes de generar plano y descargar 
        companyData.Get();
        lineValidation := false;
        GJL.SetFilter("Journal Batch Name", JBN);
        GJL.SetRange("Document Type", GJL."Document Type"::Payment);
        GJL.SetRange("Account Type", GJL."Account Type"::Vendor);
        GJL.SetRange("Bal. Account No.", BAN);

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
                                        Bank.SetFilter("No.", BankCode);
                                        Bank.FindFirst();
                                        seq += 1;
                                        flatFileText_lines.Append('1');

                                        tempLength := Text.StrLen(Format(seq));
                                        if tempLength < 5 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 5, '0') + Format(seq));
                                        end else begin
                                            flatFileText_lines.Append(Format(seq));
                                        end;
                                        flatFileText_lines.Append(Format(System.Today(), 0, '<Month,2><Day,2><YEAR>'));

                                        if vendorBankAccount.LyLThirdPayment then begin
                                            flatFileText_lines.Append('03');
                                            nitLine := vendorBankAccount."D365L CO ThirdNit" + Format(vendorBankAccount."D365L CO ThirdDV");

                                            vendorName := vendorBankAccount."D365L CO ThirdName";
                                            if Text.StrLen(vendorBankAccount."D365L CO ThirdName") > 22 then
                                                vendorName := Format(vendorBankAccount."D365L CO ThirdName").Substring(1, 22);
                                        end else begin
                                            if vendorData."D365L CO DIAN Ident. Type" = '31' then
                                                flatFileText_lines.Append('03');
                                            if vendorData."D365L CO DIAN Ident. Type" = '13' then
                                                flatFileText_lines.Append('01');
                                            if vendorData."D365L CO DIAN Ident. Type" = '22' then
                                                flatFileText_lines.Append('02');
                                            if vendorData."D365L CO DIAN Ident. Type" = '12' then
                                                flatFileText_lines.Append('04');
                                            if vendorData."D365L CO DIAN Ident. Type" = '41' then
                                                flatFileText_lines.Append('05');
                                            nitLine := vendorData."VAT Registration No.".Trim() + vendorData."D365L CO Verification Code";

                                            vendorName := vendorData."Search Name";
                                            if Text.StrLen(vendorData."Search Name") > 22 then
                                                vendorName := Format(vendorData."Search Name").Substring(1, 22);
                                        end;
                                        tempLength := Text.StrLen(nitLine);
                                        if tempLength < 15 then begin
                                            flatFileText_lines.Append(nitLine + GetFill(tempLength, 15, ' '));
                                        end else begin
                                            flatFileText_lines.Append(nitLine);
                                        end;

                                        vendorName := DELCHR(vendorName, '=', DELCHR(vendorName, '=', txtCharsToKeep));
                                        tempLength := Text.StrLen(vendorName);
                                        if tempLength < 22 then begin
                                            flatFileText_lines.Append(vendorName + GetFill(tempLength, 22, ' '));
                                        end else begin
                                            flatFileText_lines.Append(vendorName);
                                        end;

                                        flatFileText_lines.Append('N');
                                        flatFileText_lines.Append('   ');
                                        tempLength := Text.StrLen(vendorBankAccount."D365L CO Banks");
                                        if tempLength < 3 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 3, '0') + vendorBankAccount."D365L CO Banks");
                                        end else begin
                                            flatFileText_lines.Append(vendorBankAccount."D365L CO Banks");
                                        end;
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Ahorros" then
                                            flatFileText_lines.Append('AHO');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Corriente" then
                                            flatFileText_lines.Append('CTE');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Credito Rotativo" then
                                            flatFileText_lines.Append('CRT');
                                        tempLength := Text.StrLen(vendorBankAccount."Bank Account No.".Trim());
                                        if tempLength < 17 then begin
                                            flatFileText_lines.Append(vendorBankAccount."Bank Account No.".Trim() + GetFill(tempLength, 17, ' '));
                                        end else begin
                                            flatFileText_lines.Append(vendorBankAccount."Bank Account No.".Trim());
                                        end;
                                        flatFileText_lines.Append('CR');
                                        amountText := Format(Round(tempAmount, 0.01, '='), 0, '<Integer><Decimals,3>').Replace(',', '').Replace('.', '');
                                        tempLength := Text.StrLen(amountText);
                                        if tempLength < 14 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 14, '0') + amountText);
                                        end else begin
                                            flatFileText_lines.Append(amountText);
                                        end;
                                        flatFileText_lines.Append(FillBlank(100));

                                        tempLength := Text.StrLen(vendorData."E-Mail".Trim());
                                        if tempLength < 100 then begin
                                            flatFileText_lines.Append(vendorData."E-Mail".Trim() + GetFill(tempLength, 100, ' '));
                                        end else begin
                                            flatFileText_lines.Append(vendorData."E-Mail".Trim());
                                        end;
                                        //  flatFileText_lines.Append(FillBlank(100));

                                        flatFileText_lines.Append('1' + FillBlank(13));
                                        flatFileText_lines.Append('1' + FillBlank(13));
                                        flatFileText_lines.Append('1' + FillBlank(13));
                                        flatFileText_lines.Append('x' + FillBlank(39));
                                        flatFileText_lines.Append('COL 11  11001');

                                        if companyData."D365L CO DIAN Ident. Type" = '31' then
                                            flatFileText_lines.Append('03');
                                        if companyData."D365L CO DIAN Ident. Type" = '13' then
                                            flatFileText_lines.Append('01');
                                        if companyData."D365L CO DIAN Ident. Type" = '22' then
                                            flatFileText_lines.Append('02');
                                        if companyData."D365L CO DIAN Ident. Type" = '12' then
                                            flatFileText_lines.Append('04');
                                        if companyData."D365L CO DIAN Ident. Type" = '41' then
                                            flatFileText_lines.Append('05');

                                        nitLine := companyData."VAT Registration No.".Trim() + companyData."D365L CO Verification Code";
                                        tempLength := Text.StrLen(nitLine);
                                        if tempLength < 15 then begin
                                            flatFileText_lines.Append(nitLine + GetFill(tempLength, 15, ' '));
                                        end else begin
                                            flatFileText_lines.Append(nitLine);
                                        end;
                                        if Bank."D365L CO AccountType" = Bank."D365L CO AccountType"::"Cuenta Ahorros" then
                                            flatFileText_lines.Append('AHO');
                                        if Bank."D365L CO AccountType" = Bank."D365L CO AccountType"::"Cuenta Corriente" then
                                            flatFileText_lines.Append('CTE');
                                        if Bank."D365L CO AccountType" = Bank."D365L CO AccountType"::"Credito Rotativo" then
                                            flatFileText_lines.Append('CRT');
                                        tempLength := Text.StrLen(Bank."Bank Account No.".Trim());
                                        if tempLength < 17 then begin
                                            flatFileText_lines.Append(Bank."Bank Account No.".Trim() + GetFill(tempLength, 17, ' '));
                                        end else begin
                                            flatFileText_lines.Append(Bank."Bank Account No.".Trim());
                                        end;
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
                tmpBlob.CreateOutStream(OutStr);
                OutStr.WriteText(flatFileText_lines.ToText());
                tmpBlob.CreateInStream(InStr);
                fileName := 'FLATFILEITAU' + Format(System.Today(), 0, '<Year4><Month,2><Day,2>') + '.txt';
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
