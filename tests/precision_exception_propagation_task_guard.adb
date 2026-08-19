procedure Precision_Exception_Propagation_Task_Guard is
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
      end Worker;
   begin
      null;
   end;
exception
   when Program_Error =>
      null;
end Precision_Exception_Propagation_Task_Guard;
