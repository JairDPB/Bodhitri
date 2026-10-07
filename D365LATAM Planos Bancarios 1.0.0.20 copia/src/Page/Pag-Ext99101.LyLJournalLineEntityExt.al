/// <summary>
/// Extension de pagina de diario de pagos para incluir campos adicionales para la generacion de planos bancarios
/// </summary>
pageextension 99101 "LyL JournalLineEntityExt" extends "Payment Journal"
{
    actions
    {
        modify(ExportPaymentsToFile)
        {
            Visible = false;
        }
        addfirst("Electronic Payments")
        {
            action("LyL ExportPaymentsToFile")
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Exportar Plano';
                Ellipsis = true;
                Image = ExportFile;
                Promoted = true;
                PromotedCategory = Category4;
                PromotedIsBig = true;
                Enabled = NOT OpenApprovalEntriesOnBatchOrAnyJnlLineExist;
                ToolTip = 'Export a file with the payment information on the journal lines.';

                trigger OnAction();
                var
                    //   CU: Codeunit "LyL FlatFileBancolombia";
                    bank: Record "Bank Account";
                    exportConfig: Record "Bank Export/Import Setup";
                    CU_no: Integer;
                    ApprovalsMgmt: Codeunit "Approvals Mgmt.";
                    GenJournalBatch: Record "Gen. Journal Batch";
                begin
                    if not GenJournalBatch.Get(Rec.GetRangeMax("Journal Template Name"), Rec."Journal Batch Name") then
                        exit;

                    OpenApprovalEntriesOnJnlBatchExist := ApprovalsMgmt.HasOpenApprovalEntries(GenJournalBatch.RecordId);
                    OpenApprovalEntriesOnBatchOrAnyJnlLineExist :=
                    OpenApprovalEntriesOnJnlBatchExist or
                    ApprovalsMgmt.HasAnyOpenJournalLineApprovalEntries(Rec."Journal Template Name", Rec."Journal Batch Name");


                    bank.SetFilter("No.", Rec."Bal. Account No.");
                    bank.FindFirst();
                    if bank."Payment Export Format" <> '' then begin
                        exportConfig.SetFilter(Code, bank."Payment Export Format");
                        exportConfig.FindFirst();
                        if exportConfig."Processing Codeunit ID" <> 0 then begin
                            CU_no := exportConfig."Processing Codeunit ID";
                            Codeunit.Run(CU_no, Rec);
                        end else begin
                            Message('No se a establecido un codeunit para el procesamiento de plano para  ' + bank.Name);
                        end;

                    end else begin
                        Message('No se a establecido un formato para la descarga de plano para ' + bank.Name);
                    end;
                end;
            }
            /*     action("LyL ExportFile")
                 {
                     Caption = 'Exportar Archivo Plano';
                     ApplicationArea = all;

                     trigger OnAction();
                     var
                         CU: Codeunit "LyL FlatFileBancolombia";
                         bank: Record "Bank Account";
                         exportConfig: Record "Bank Export/Import Setup";
                         CU_no: Integer;
                     begin
                         bank.SetFilter("No.", Rec."Bal. Account No.");
                         bank.FindFirst();
                         exportConfig.SetFilter(Code, bank."Payment Export Format");
                         exportConfig.FindFirst();
                         CU_no := exportConfig."Processing Codeunit ID";

                         // CU.FlatFileBancolombia(Rec."Journal Batch Name");
                         Codeunit.Run(CU_no, Rec);
                     end;
                 }*/

        }
    }
    var
        OpenApprovalEntriesOnBatchOrAnyJnlLineExist: Boolean;
        OpenApprovalEntriesOnJnlBatchExist: Boolean;
}
