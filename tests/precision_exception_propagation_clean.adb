procedure Precision_Exception_Propagation_Clean is
   procedure Fail is
   begin
      raise Program_Error;
   end Fail;
begin
   Fail;
exception
   when Program_Error =>
      null;
end Precision_Exception_Propagation_Clean;
