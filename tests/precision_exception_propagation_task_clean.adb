procedure Precision_Exception_Propagation_Task_Clean is
   procedure Fail is
   begin
      raise Program_Error;
   end Fail;
begin
   declare
      task Worker;
      task body Worker is
      begin
         Fail;
      exception
         when Program_Error =>
            null;
      end Worker;
   begin
      null;
   end;
end Precision_Exception_Propagation_Task_Clean;
