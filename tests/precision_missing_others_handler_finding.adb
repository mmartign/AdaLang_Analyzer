procedure Precision_Missing_Others_Handler_Finding is
   X : Integer := 0;
begin
   X := X + 1;
exception
   when Constraint_Error =>
      X := 0;
end Precision_Missing_Others_Handler_Finding;
