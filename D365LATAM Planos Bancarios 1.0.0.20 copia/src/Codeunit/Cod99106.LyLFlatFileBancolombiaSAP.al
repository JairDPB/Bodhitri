/// <summary>
/// Codeunit para generar archivo plano de pagos a proveedores banco Bancolombia SAP
/// </summary>
codeunit 99106 "D365L CO FileBancolombiaSAP"
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
                                        totalCredit += tempAmount;
                                        BankCode := GJL."Bal. Account No.";

                                        flatFileText_lines.Append('6');
                                        tempLength := Text.StrLen(vendorData."VAT Registration No.");
                                        if tempLength < 15 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 15, '0') + vendorData."VAT Registration No.");
                                        end else begin
                                            flatFileText_lines.Append(vendorData."VAT Registration No.");
                                        end;

                                        nitLine := vendorData."Search Name";
                                        if Text.StrLen(vendorData."Search Name") > 18 then
                                            nitLine := Format(vendorData."Search Name").Substring(1, 18);
                                        nitLine := DELCHR(nitLine, '=', DELCHR(nitLine, '=', txtCharsToKeep));
                                        tempLength := Text.StrLen(nitLine);
                                        if tempLength < 18 then begin
                                            flatFileText_lines.Append(nitLine + GetFill(tempLength, 18, ' '));
                                        end else begin
                                            flatFileText_lines.Append(nitLine);
                                        end;

                                        tempLength := Text.StrLen(vendorBankAccount."D365L CO Banks");
                                        if tempLength < 9 then begin
                                            if tempLength < 4 then begin
                                                flatFileText_lines.Append(GetFill(tempLength, 7, '0') + '10' + vendorBankAccount."D365L CO Banks");
                                            end else
                                                flatFileText_lines.Append(GetFill(tempLength, 9, '0') + vendorBankAccount."D365L CO Banks");
                                        end else begin
                                            flatFileText_lines.Append(vendorBankAccount."D365L CO Banks");
                                        end;

                                        tempLength := Text.StrLen(vendorBankAccount."Bank Account No.");
                                        if tempLength < 17 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 17, '0') + vendorBankAccount."Bank Account No.");
                                        end else begin
                                            flatFileText_lines.Append(vendorBankAccount."Bank Account No.");
                                        end;
                                        flatFileText_lines.Append('S');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Ahorros" then
                                            flatFileText_lines.Append('37');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Corriente" then
                                            flatFileText_lines.Append('27');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Credito Rotativo" then
                                            flatFileText_lines.Append('27');

                                        amountText := Format(Round(tempAmount, 0.01, '='), 0, '<Integer>').Replace(',', '').Replace('.', '');
                                        tempLength := Text.StrLen(amountText);
                                        if tempLength < 10 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 10, '0') + amountText);
                                        end else begin
                                            flatFileText_lines.Append(amountText);
                                        end;

                                        tempLength := Text.StrLen(GJL."Message to Recipient");
                                        if tempLength < 9 then begin
                                            flatFileText_lines.Append(GJL."Message to Recipient" + GetFill(tempLength, 9, ' '));
                                        end else begin
                                            flatFileText_lines.Append(GJL."Message to Recipient".Substring(1, 9));
                                        end;
                                        flatFileText_lines.Append(FillBlank(13));
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
                // HEADER
                // Tipo de Registro
                flatFileText.Append('1');
                // NIT longitud 15 0s a la izq
                tempLength := Text.StrLen(companyData."VAT Registration No.");
                if tempLength < 10 then begin
                    flatFileText.Append(GetFill(tempLength, 10, '0') + companyData."VAT Registration No.");
                end else begin
                    flatFileText.Append(companyData."VAT Registration No.");
                end;

                tempLength := Text.StrLen(companyData.Name);
                if tempLength < 16 then begin
                    flatFileText.Append(companyData.Name + GetFill(tempLength, 16, ' '));
                end else begin
                    flatFileText.Append(companyData.Name);
                end;

                //  flatFileText.Append('I');
                //  flatFileText.Append(FillBlank(15));

                flatFileText.Append('220'); // segun tabla - 220 pago a proveedores
                flatFileText.Append('PAGOPROVEE');
                flatFileText.Append(Format(System.Today(), 0, '<Year><Month,2><Day,2>'));
                flatFileText.Append('A');
                flatFileText.Append(Format(System.Today(), 0, '<Year><Month,2><Day,2>'));

                totallineCount := Format(GJL_list.Count());
                tempLength := Text.StrLen(totallineCount);
                if tempLength < 6 then begin
                    flatFileText.Append(GetFill(tempLength, 6, '0') + totallineCount);
                end else begin
                    flatFileText.Append(totallineCount);
                end;

                flatFileText.Append(GetFill(0, 12, '0'));
                amountText := Format(Round(totalCredit, 0.01, '='), 0, '<Integer>').Replace(',', '').Replace('.', '');
                tempLength := Text.StrLen(amountText);
                if tempLength < 12 then begin
                    flatFileText.Append(GetFill(tempLength, 12, '0') + amountText);
                end else begin
                    flatFileText.Append(amountText);
                end;

                Bank.SetFilter("No.", BankCode);
                Bank.FindFirst();
                tempLength := Text.StrLen(Bank."Bank Account No.");
                if tempLength < 11 then begin
                    flatFileText.Append(GetFill(tempLength, 11, '0') + Bank."Bank Account No.");
                end else begin
                    flatFileText.Append(Bank."Bank Account No.");
                end;
                if Bank."D365L CO AccountType" = Bank."D365L CO AccountType"::"Cuenta Ahorros" then
                    flatFileText.Append('S');
                if Bank."D365L CO AccountType" = Bank."D365L CO AccountType"::"Cuenta Corriente" then
                    flatFileText.Append('D');
                if Bank."D365L CO AccountType" = Bank."D365L CO AccountType"::"Credito Rotativo" then
                    flatFileText.Append('C');

                //    flatFileText.Append(FillBlank(149));
                flatFileText.AppendLine();

                tmpBlob.CreateOutStream(OutStr);
                OutStr.WriteText(flatFileText.ToText() + flatFileText_lines.ToText());
                tmpBlob.CreateInStream(InStr);
                fileName := 'FLATFILEBANCOL' + Format(System.Today(), 0, '<Year><Month,2><Day,2>') + '.txt';
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
