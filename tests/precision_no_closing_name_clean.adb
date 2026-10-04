procedure Precision_No_Closing_Name_Clean is
   procedure Inner is
   begin
      null;
   end Inner;

   task type Worker;

   task body Worker is
   begin
      null;
   end Worker;
begin
   Inner;
end Precision_No_Closing_Name_Clean;
