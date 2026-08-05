procedure Precision_Abort_Finding is
   task type Worker;

   task body Worker is
   begin
      null;
   end Worker;

   W : Worker;
begin
   abort W;
end Precision_Abort_Finding;
