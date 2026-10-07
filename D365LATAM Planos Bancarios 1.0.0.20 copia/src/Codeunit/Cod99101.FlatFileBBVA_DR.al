/// <summary>
/// Codeunit para generar un archivo plano para pagos a proveedores BBVA
/// DelRio
/// </summary>
codeunit 99110 "D365L CO FlatFileBBVA_DR"
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
        DVvendor: Text;
    begin
        txtCharsToKeep := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 ';
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

                                        if vendorData."D365L CO DIAN Ident. Type" = '13' then
                                            flatFileText_lines.Append('01');
                                        if vendorData."D365L CO DIAN Ident. Type" = '21' then
                                            flatFileText_lines.Append('02');
                                        if vendorData."D365L CO DIAN Ident. Type" = '31' then
                                            flatFileText_lines.Append('03');
                                        if vendorData."D365L CO DIAN Ident. Type" = '12' then
                                            flatFileText_lines.Append('04');
                                        if vendorData."D365L CO DIAN Ident. Type" = '41' then
                                            flatFileText_lines.Append('05');

                                        tempLength := Text.StrLen(vendorData."VAT Registration No.") + 1;
                                        if (vendorData."D365L CO DIAN Ident. Type" = '31') and (vendorData."D365L CO Verification Code" <> '') then begin
                                            DVvendor := vendorData."D365L CO Verification Code";
                                        end else
                                            DVvendor := '0';

                                        DVvendor := vendorData."VAT Registration No." + DVvendor;
                                        if tempLength < 16 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 16, '0') + DVvendor);
                                        end else begin
                                            flatFileText_lines.Append(DVvendor);
                                        end;
                                        flatFileText_lines.Append('1'); // tipo de pago 1: abono a cuenta

                                        // validar: codigo del banco
                                        tempLength := Text.StrLen(vendorBankAccount."D365L CO Banks");
                                        if tempLength < 4 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 4, '0') + vendorBankAccount."D365L CO Banks");
                                        end else begin
                                            flatFileText_lines.Append(vendorBankAccount."D365L CO Banks");
                                        end;

                                        // tipo de cuenta 
                                        if (vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Ahorros") then
                                            flatFileText_lines.Append('000000000000000002');
                                        if (vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Corriente") then
                                            flatFileText_lines.Append('000000000000000001');

                                        tempLength := Text.StrLen(vendorBankAccount."Bank Account No.");
                                        if tempLength < 12 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 12, '0') + vendorBankAccount."Bank Account No.");
                                        end else
                                            flatFileText_lines.Append(vendorBankAccount."Bank Account No.");

                                        flatFileText_lines.Append(FillBlank(5));

                                        amountText := Format(Round(tempAmount, 0.01, '='), 0, '<Integer><Decimals,3>').Replace(',', '').Replace('.', '');
                                        tempLength := Text.StrLen(amountText);
                                        if tempLength < 16 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 16, '0') + amountText);
                                        end else begin
                                            flatFileText_lines.Append(amountText);
                                        end;
                                        flatFileText_lines.Append(Format(System.Today(), 0, '<Year4><Month,2><Day,2>'));
                                        flatFileText_lines.Append('0000');

                                        nitLine := vendorData."Search Name";
                                        if Text.StrLen(vendorData."Search Name") > 36 then
                                            nitLine := Format(vendorData."Search Name").Substring(1, 36);
                                        nitLine := DELCHR(nitLine, '=', DELCHR(nitLine, '=', txtCharsToKeep));
                                        tempLength := Text.StrLen(nitLine);
                                        if tempLength < 36 then begin
                                            flatFileText_lines.Append(nitLine + GetFill(tempLength, 36, ' '));
                                        end else begin
                                            flatFileText_lines.Append(nitLine);
                                        end;
                                        nitLine := vendorData.City;
                                        if Text.StrLen(vendorData.City) > 120 then
                                            nitLine := Format(vendorData.City).Substring(1, 120);
                                        nitLine := DELCHR(nitLine, '=', DELCHR(nitLine, '=', txtCharsToKeep));
                                        tempLength := Text.StrLen(nitLine);
                                        if tempLength < 120 then begin
                                            flatFileText_lines.Append(nitLine + GetFill(tempLength, 120, ' '));
                                        end else begin
                                            flatFileText_lines.Append(nitLine);
                                        end;

                                        nitLine := GJL.Description;
                                        if Text.StrLen(GJL.Description) > 40 then
                                            nitLine := Format(GJL.Description).Substring(1, 40);
                                        nitLine := DELCHR(nitLine, '=', DELCHR(nitLine, '=', txtCharsToKeep));
                                        tempLength := Text.StrLen(nitLine);
                                        if tempLength < 40 then begin
                                            flatFileText_lines.Append(nitLine + GetFill(tempLength, 40, ' '));
                                        end else begin
                                            flatFileText_lines.Append(nitLine);
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
                fileName := 'FLATFILEBBVA' + Format(System.Today(), 0, '<Year4><Month,2><Day,2>') + '.txt';
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