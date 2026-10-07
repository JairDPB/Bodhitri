/// <summary>
/// Codeunit para generar archivo plano de pagos a proveedores banco de Occidente.
/// </summary>
codeunit 99109 "D365L CO FileBancoOccidente"
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
        countLine: Integer;
    begin
        txtCharsToKeep := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 ';
        // crear un metodo de validacion antes de generar plano y descargar 
        companyData.Get();
        lineValidation := false;
        GJL.SetFilter("Journal Batch Name", JBN);
        GJL.SetRange("Document Type", GJL."Document Type"::Payment);
        GJL.SetRange("Account Type", GJL."Account Type"::Vendor);
        GJL.SetRange("Bal. Account No.", BAN);
        countLine := 0;
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

                                        countLine += 1;

                                        flatFileText_lines.Append('2');
                                        tempLength := Text.StrLen(Format(countLine));
                                        if tempLength < 4 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 4, '0') + Format(countLine));
                                        end else begin
                                            flatFileText_lines.Append(Format(countLine));
                                        end;
                                        tempLength := Text.StrLen(Bank."Bank Account No.");
                                        if tempLength < 16 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 16, '0') + Bank."Bank Account No.");
                                        end else begin
                                            flatFileText_lines.Append(Bank."Bank Account No.");
                                        end;

                                        nitLine := vendorData."Search Name";
                                        if Text.StrLen(vendorData."Search Name") > 30 then
                                            nitLine := Format(vendorData."Search Name").Substring(1, 30);
                                        nitLine := DELCHR(nitLine, '=', DELCHR(nitLine, '=', txtCharsToKeep));
                                        tempLength := Text.StrLen(nitLine);
                                        if tempLength < 30 then begin
                                            flatFileText_lines.Append(nitLine + GetFill(tempLength, 30, ' '));
                                        end else begin
                                            flatFileText_lines.Append(nitLine);
                                        end;
                                        tempLength := Text.StrLen(vendorData."VAT Registration No.");
                                        if tempLength < 10 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 10, '0') + vendorData."VAT Registration No.");
                                        end else begin
                                            flatFileText_lines.Append(vendorData."VAT Registration No.");
                                        end;
                                        flatFileText_lines.Append(vendorData."D365L CO Verification Code");
                                        tempLength := Text.StrLen(vendorBankAccount."D365L CO Banks");
                                        if tempLength < 4 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 4, '0') + vendorBankAccount."D365L CO Banks");
                                        end else begin
                                            flatFileText_lines.Append(vendorBankAccount."D365L CO Banks");
                                        end;
                                        flatFileText_lines.Append(Format(System.Today(), 0, '<Year4><Month,2><Day,2>'));

                                        //-+-------------------
                                        if vendorBankAccount."D365L CO Banks" = '23' then begin
                                            flatFileText_lines.Append('2');
                                        end else begin
                                            flatFileText_lines.Append('3');
                                        end;
                                        amountText := Format(Round(tempAmount, 0.01, '='), 0, '<Integer>').Replace(',', '').Replace('.', '');
                                        tempLength := Text.StrLen(amountText);
                                        if tempLength < 15 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 15, '0') + amountText);
                                        end else begin
                                            flatFileText_lines.Append(amountText);
                                        end;
                                        tempLength := Text.StrLen(vendorBankAccount."Bank Account No.");
                                        if tempLength < 16 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 16, '0') + vendorBankAccount."Bank Account No.");
                                        end else begin
                                            flatFileText_lines.Append(vendorBankAccount."Bank Account No.");
                                        end;

                                        /* tempLength := Text.StrLen(GJL."Document No.");
                                         if tempLength < 12 then begin
                                             flatFileText_lines.Append(GetFill(tempLength, 12, ' ') + GJL."Document No.");
                                         end else begin
                                             flatFileText_lines.Append(GJL."Document No.");
                                         end;*/
                                        flatFileText_lines.Append('000000000000');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Ahorros" then
                                            flatFileText_lines.Append('A');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Corriente" then
                                            flatFileText_lines.Append('C');

                                        flatFileText_lines.Append(FillBlank(80));

                                        flatFileText_lines.AppendLine();
                                        lineValidation := true;
                                    end;
                                end;
                            end;
                        end;
                    end;
                until GJL.Next() = 0;
                flatFileText_lines.Append('39999');
                totallineCount := Format(GJL_list.Count());
                tempLength := Text.StrLen(totallineCount);
                if tempLength < 4 then begin
                    flatFileText_lines.Append(GetFill(tempLength, 4, '0') + totallineCount);
                end else begin
                    flatFileText_lines.Append(totallineCount);
                end;
                amountText := Format(Round(totalCredit, 0.01, '='), 0, '<Integer>').Replace(',', '').Replace('.', '');
                tempLength := Text.StrLen(amountText);
                if tempLength < 18 then begin
                    flatFileText_lines.Append(GetFill(tempLength, 18, '0') + amountText);
                end else begin
                    flatFileText_lines.Append(amountText);
                end;
                flatFileText_lines.Append(GetFill(0, 172, '0'));
            end;

            if lineValidation then begin
                // HEADER
                flatFileText.Append('10000');
                flatFileText.Append(Format(System.Today(), 0, '<Year4><Month,2><Day,2>'));
                totallineCount := Format(GJL_list.Count());
                tempLength := Text.StrLen(totallineCount);
                if tempLength < 4 then begin
                    flatFileText.Append(GetFill(tempLength, 4, '0') + totallineCount);
                end else begin
                    flatFileText.Append(totallineCount);
                end;
                amountText := Format(Round(totalCredit, 0.01, '='), 0, '<Integer>').Replace(',', '').Replace('.', '');
                tempLength := Text.StrLen(amountText);
                if tempLength < 18 then begin
                    flatFileText.Append(GetFill(tempLength, 18, '0') + amountText);
                end else begin
                    flatFileText.Append(amountText);
                end;

                tempLength := Text.StrLen(Bank."Bank Account No.");
                if tempLength < 16 then begin
                    flatFileText.Append(GetFill(tempLength, 16, '0') + Bank."Bank Account No.");
                end else begin
                    flatFileText.Append(Bank."Bank Account No.");
                end;

                flatFileText.Append('000000');
                flatFileText.Append(GetFill(0, 142, '0'));
                flatFileText.AppendLine();

                tmpBlob.CreateOutStream(OutStr);
                OutStr.WriteText(flatFileText.ToText() + flatFileText_lines.ToText());
                tmpBlob.CreateInStream(InStr);
                fileName := 'FLATFILEOCCIDEN' + Format(System.Today(), 0, '<Year><Month,2><Day,2>') + '.txt';
                if not Bank."D365L CO Encrypt pgp" then
                    DownloadFromStream(InStr, '', '', '', fileName);
                if Bank."D365L CO Encrypt pgp" then begin
                    if ServiceAPI.PutBlob(FileName.Replace('/', ''), InStr) then
                        Message('El archivo ' + Format(FileName.Replace('/', '')) + ' se subio a Blob Store')
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
