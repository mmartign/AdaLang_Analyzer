procedure Precision_Exception_Propagation_Guard is
   procedure Fail is
   begin
      raise Program_Error;
   end Fail;
begin
   Fail;
end Precision_Exception_Propagation_Guard;
