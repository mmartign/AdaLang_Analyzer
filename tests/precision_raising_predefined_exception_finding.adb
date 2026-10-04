procedure Precision_Raising_Predefined_Exception_Finding (X : Integer) is
   Bad_Value : exception renames Constraint_Error;
begin
   if X < 0 then
      raise Bad_Value;
   end if;
end Precision_Raising_Predefined_Exception_Finding;
