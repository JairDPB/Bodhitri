/// <summary>
/// Codeunit para generar un archivo plano para pagos a proveedores Davivienda Corredores
/// </summary>
codeunit 99102 "D365L CO FlatFileDavCorr"
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
        lineValidation: Boolean;
        totallineCount: Text;
        txtCharsToKeep: Text;
        ServiceAPI: Codeunit "D365L CO Blob Service API";
        filePref: Text;
    begin
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
                                        totalCredit += Round(tempAmount, 0.01, '=');
                                        BankCode := GJL."Bal. Account No.";

                                        flatFileText_lines.Append('2,');
                                        flatFileText_lines.Append(Format(System.Today(), 0, '<Day,2><Month,2><Year4>') + ',');
                                        if vendorBankAccount.LyLThirdPayment then begin
                                            flatFileText_lines.Append(vendorBankAccount."D365L CO ThirdNit" + ',');
                                            flatFileText_lines.Append(Format(vendorBankAccount."D365L CO ThirdDV") + ',');
                                        end else begin
                                            flatFileText_lines.Append(vendorData."VAT Registration No." + ',');
                                            flatFileText_lines.Append(vendorData."D365L CO Verification Code" + ',');
                                        end;

                                        if vendorData."D365L CO DIAN Ident. Type" = '13' then
                                            flatFileText_lines.Append('CC,');
                                        if vendorData."D365L CO DIAN Ident. Type" = '31' then
                                            flatFileText_lines.Append('NIT,');
                                        nitLine := vendorData."Search Name";
                                        if Text.StrLen(vendorData."Search Name") > 30 then
                                            nitLine := Format(vendorData."Search Name").Substring(1, 30);
                                        nitLine := DELCHR(nitLine, '=', DELCHR(nitLine, '=', txtCharsToKeep));
                                        flatFileText_lines.Append(nitLine + ',');
                                        flatFileText_lines.Append(Format(System.Today(), 0, '<Day,2><Month,2><Year4>') + ',');
                                        flatFileText_lines.Append(vendorBankAccount."D365L CO Banks" + ',');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Ahorros" then
                                            flatFileText_lines.Append('CAH,');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Corriente" then
                                            flatFileText_lines.Append('CCO,');
                                        flatFileText_lines.Append(vendorBankAccount."Bank Account No.".Trim() + ',');
                                        amountText := Format(Round(tempAmount, 0.01, '='), 0, '<Integer>').Replace('.', '').Replace(',', '');
                                        flatFileText_lines.Append(amountText);
                                        flatFileText_lines.Append(',,,');
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
                Bank.SetFilter("No.", BankCode);
                Bank.FindFirst();
                flatFileText.Append('1,');
                flatFileText.Append(Format(System.Today(), 0, '<Day,2><Month,2><Year4>') + ',');
                flatFileText.Append(companyData."VAT Registration No." + ',');
                flatFileText.Append(companyData."D365L CO Verification Code" + ',');
                flatFileText.Append('NIT,');
                flatFileText.Append(Format(System.Today(), 0, '<Day,2><Month,2><Year4>') + ',');
                totallineCount := Format(GJL_list.Count());
                flatFileText.Append(totallineCount + ',');
                amountText := Format(Round(totalCredit, 0.01, '='), 0, '<Integer>').Replace('.', '').Replace(',', '');
                flatFileText.Append(amountText);
                flatFileText.AppendLine();

                tmpBlob.CreateOutStream(OutStr);
                OutStr.WriteText(flatFileText.ToText() + flatFileText_lines.ToText());
                tmpBlob.CreateInStream(InStr);

                tempLength := Text.StrLen(companyData."VAT Registration No.".Trim());
                nitLine := companyData."VAT Registration No.".Trim();
                case nitLine of
                    '800175087':
                        filePref := 'GP_';
                    '901289080':
                        filePref := 'PR_';
                    '830121797':
                        filePref := 'PI_';
                    '901583881':
                        filePref := 'FH_';
                end;
                amountText := Format(Round(totalCredit, 0.01, '='), 0, '<Integer>').Replace('.', ',');
                if tempLength < 15 then begin
                    fileName := GetFill(tempLength, 15, '0') + companyData."VAT Registration No.".Trim() + '_99_' + amountText + '.csv';
                end else begin
                    fileName := companyData."VAT Registration No.".Trim() + '_99_' + amountText + '.csv';
                end;
                fileName := filePref + fileName;
                if not Bank."D365L CO Encrypt pgp" then
                    DownloadFromStream(InStr, '', '', '', fileName);
                if Bank."D365L CO Encrypt pgp" then begin
                    if ServiceAPI.PutBlob(FileName.Replace('/', ''), InStr) then
                        Message('Archivo ' + Format(FileName.Replace('/', '')) + ' en proceso de encriptado')
                    else
                        Message('Error, al subir archivo ' + Format(FileName.Replace('/', '')) + ' a Blob Store')
                end;
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
