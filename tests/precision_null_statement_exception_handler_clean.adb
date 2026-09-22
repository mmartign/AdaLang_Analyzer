procedure Precision_Null_Statement_Exception_Handler_Clean (X : Integer) is
begin
   begin
      if X = 0 then
         raise Program_Error;
      end if;
   exception
      when Program_Error =>
         null;
   end;
end Precision_Null_Statement_Exception_Handler_Clean;
