procedure Precision_Separate_Numeric_Error_Handler_Finding is
   X : Integer := 0;
begin
   X := X + 1;
exception
   when Constraint_Error =>
      X := 0;
end Precision_Separate_Numeric_Error_Handler_Finding;
