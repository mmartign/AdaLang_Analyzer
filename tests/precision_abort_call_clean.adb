procedure Precision_Abort_Call_Clean is
   procedure Abort_Operation is
   begin
      null;
   end Abort_Operation;
begin
   Abort_Operation;
end Precision_Abort_Call_Clean;
