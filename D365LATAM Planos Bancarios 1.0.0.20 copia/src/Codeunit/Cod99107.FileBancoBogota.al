/// <summary>
/// Codeunit para generar archivo plano de pagos a proveedores banco Banco Bogota
/// </summary>
codeunit 99107 "D365L CO FileBancoBogota"
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

                                        flatFileText_lines.Append('2');

                                        if vendorData."D365L CO DIAN Ident. Type" = '13' then
                                            flatFileText_lines.Append('C');
                                        if vendorData."D365L CO DIAN Ident. Type" = '21' then
                                            flatFileText_lines.Append('E');
                                        if vendorData."D365L CO DIAN Ident. Type" = '31' then
                                            flatFileText_lines.Append('N');
                                        if vendorData."D365L CO DIAN Ident. Type" = '12' then
                                            flatFileText_lines.Append('T');
                                        if vendorData."D365L CO DIAN Ident. Type" = '41' then
                                            flatFileText_lines.Append('P');

                                        if (vendorData."D365L CO DIAN Ident. Type" = '31') then begin
                                            tempLength := Text.StrLen(vendorData."VAT Registration No.");
                                            if tempLength < 10 then begin
                                                flatFileText_lines.Append(GetFill(tempLength, 10, '0') + vendorData."VAT Registration No.");
                                            end else begin
                                                flatFileText_lines.Append(vendorData."VAT Registration No.");
                                            end;
                                            if (vendorData."D365L CO Verification Code" <> '') then begin
                                                flatFileText_lines.Append(vendorData."D365L CO Verification Code");
                                            end else
                                                flatFileText_lines.Append('0');
                                        end else begin
                                            tempLength := Text.StrLen(vendorData."VAT Registration No.");
                                            if tempLength < 11 then begin
                                                flatFileText_lines.Append(GetFill(tempLength, 11, '0') + vendorData."VAT Registration No.");
                                            end else begin
                                                flatFileText_lines.Append(vendorData."VAT Registration No.");
                                            end;
                                        end;


                                        nitLine := vendorData."Search Name";
                                        if Text.StrLen(vendorData."Search Name") > 40 then
                                            nitLine := Format(vendorData."Search Name").Substring(1, 40);
                                        nitLine := DELCHR(nitLine, '=', DELCHR(nitLine, '=', txtCharsToKeep));
                                        tempLength := Text.StrLen(nitLine);
                                        if tempLength < 40 then begin
                                            flatFileText_lines.Append(nitLine + GetFill(tempLength, 40, ' '));
                                        end else begin
                                            flatFileText_lines.Append(nitLine);
                                        end;
                                        flatFileText_lines.Append('0');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Ahorros" then
                                            flatFileText_lines.Append('2');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Cuenta Corriente" then
                                            flatFileText_lines.Append('1');
                                        if vendorBankAccount."D365L CO AccountType" = vendorBankAccount."D365L CO AccountType"::"Credito Rotativo" then
                                            flatFileText_lines.Append('5');
                                        tempLength := Text.StrLen(vendorBankAccount."Bank Account No.");
                                        if tempLength < 17 then begin
                                            flatFileText_lines.Append(vendorBankAccount."Bank Account No." + GetFill(tempLength, 17, ' '));
                                        end else begin
                                            flatFileText_lines.Append(vendorBankAccount."Bank Account No.");
                                        end;
                                        amountText := Format(Round(tempAmount, 0.01, '='), 0, '<Integer>').Replace(',', '').Replace('.', '');
                                        tempLength := Text.StrLen(amountText);
                                        if tempLength < 18 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 18, '0') + amountText);
                                        end else begin
                                            flatFileText_lines.Append(amountText);
                                        end;
                                        flatFileText_lines.Append('A000');
                                        tempLength := Text.StrLen(vendorBankAccount."D365L CO Banks");
                                        if tempLength < 3 then begin
                                            flatFileText_lines.Append(GetFill(tempLength, 3, '0') + vendorBankAccount."D365L CO Banks");
                                        end else begin
                                            flatFileText_lines.Append(vendorBankAccount."D365L CO Banks");
                                        end;
                                        flatFileText_lines.Append('0001'); //pendiente ciudad
                                        flatFileText_lines.Append(FillBlank(80));
                                        flatFileText_lines.Append('0');

                                        /*tempLength := Text.StrLen(GJL."Document No.");
                                        if tempLength < 10 then begin
                                            flatFileText_lines.Append(GJL."Document No." + GetFill(tempLength, 10, ' '));
                                        end else begin
                                            flatFileText_lines.Append(Format(GJL."Document No.").Substring(1, 9));
                                        end;*/
                                        flatFileText_lines.Append('0000000000');

                                        flatFileText_lines.Append('N');
                                        flatFileText_lines.Append(FillBlank(8));
                                        flatFileText_lines.Append(FillBlank(18));
                                        flatFileText_lines.Append(FillBlank(22));
                                        flatFileText_lines.Append('N');
                                        flatFileText_lines.Append(FillBlank(8));

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
                flatFileText.Append('1');
                flatFileText.Append(Format(System.Today(), 0, '<Year4><Month,2><Day,2>'));
                flatFileText.Append(GetFill(0, 24, '0'));

                Bank.SetFilter("No.", BankCode);
                Bank.FindFirst();

                if Bank."D365L CO AccountType" = Bank."D365L CO AccountType"::"Cuenta Ahorros" then
                    flatFileText.Append('2');
                if Bank."D365L CO AccountType" = Bank."D365L CO AccountType"::"Cuenta Corriente" then
                    flatFileText.Append('1');
                if Bank."D365L CO AccountType" = Bank."D365L CO AccountType"::"Credito Rotativo" then
                    flatFileText.Append('5');
                flatFileText.Append(GetFill(0, 6, '0'));

                tempLength := Text.StrLen(Bank."Bank Account No.");
                if (Bank."D365L CO AccountType" = Bank."D365L CO AccountType"::"Cuenta Ahorros")
                or (Bank."D365L CO AccountType" = Bank."D365L CO AccountType"::"Cuenta Corriente") then begin
                    flatFileText.Append('00');
                    if tempLength < 9 then begin
                        flatFileText.Append(GetFill(tempLength, 9, '0') + Bank."Bank Account No.");
                    end else begin
                        flatFileText.Append(Bank."Bank Account No.");
                    end;
                end else begin
                    if tempLength < 11 then begin
                        flatFileText.Append(GetFill(tempLength, 11, '0') + Bank."Bank Account No.");
                    end else begin
                        flatFileText.Append(Bank."Bank Account No.");
                    end;
                end;

                tempLength := Text.StrLen(companyData.Name);
                if tempLength < 40 then begin
                    flatFileText.Append(companyData.Name + GetFill(tempLength, 40, ' '));
                end else begin
                    flatFileText.Append(companyData.Name);
                end;

                tempLength := Text.StrLen(companyData."VAT Registration No.") + 1;
                if tempLength < 11 then begin
                    flatFileText.Append(GetFill(tempLength, 11, '0') + companyData."VAT Registration No." + companyData."D365L CO Verification Code");
                end else begin
                    flatFileText.Append(companyData."VAT Registration No." + companyData."D365L CO Verification Code");
                end;
                flatFileText.Append('002');
                flatFileText.Append('0001');  // pendiente cod ciudad
                flatFileText.Append(Format(System.Today(), 0, '<Year4><Month,2><Day,2>'));
                flatFileText.Append(Format(Bank."Bank Account No.").Substring(1, 3)); // pendiente oficina

                if companyData."D365L CO DIAN Ident. Type" = '13' then
                    flatFileText.Append('C');
                if companyData."D365L CO DIAN Ident. Type" = '21' then
                    flatFileText.Append('E');
                if companyData."D365L CO DIAN Ident. Type" = '31' then
                    flatFileText.Append('N');
                if companyData."D365L CO DIAN Ident. Type" = '12' then
                    flatFileText.Append('T');
                if companyData."D365L CO DIAN Ident. Type" = '41' then
                    flatFileText.Append('P');

                flatFileText.Append(FillBlank(49));
                flatFileText.Append(FillBlank(80));

                flatFileText.AppendLine();

                tmpBlob.CreateOutStream(OutStr);
                OutStr.WriteText(flatFileText.ToText() + flatFileText_lines.ToText());
                tmpBlob.CreateInStream(InStr);
                fileName := 'FLATFILEBOGT' + Format(System.Today(), 0, '<Year><Month,2><Day,2>') + '.txt';
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
