procedure Precision_Separate_Numeric_Error_Handler_Clean is
   X : Integer := 0;
begin
   X := X + 1;
exception
   when Constraint_Error | Numeric_Error =>
      X := 0;
   when Program_Error =>
      X := 1;
end Precision_Separate_Numeric_Error_Handler_Clean;
