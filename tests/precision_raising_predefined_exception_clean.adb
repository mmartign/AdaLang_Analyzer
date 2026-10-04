procedure Precision_Raising_Predefined_Exception_Clean (X : Integer) is
   Bad_Value : exception;
begin
   if X < 0 then
      raise Bad_Value;
   end if;
exception
   when Constraint_Error =>
      raise;
end Precision_Raising_Predefined_Exception_Clean;
