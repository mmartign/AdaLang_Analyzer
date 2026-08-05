procedure Precision_Exception_Handler_Specific_Empty is
begin
   null;
exception
   when Constraint_Error =>
      null;
end Precision_Exception_Handler_Specific_Empty;
