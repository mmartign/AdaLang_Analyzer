procedure Precision_Missing_Others_Handler_Clean is
   X : Integer := 0;

   procedure No_Handler is
   begin
      X := X + 2;
   end No_Handler;
begin
   X := X + 1;
   No_Handler;
exception
   when Constraint_Error =>
      X := 0;
   when others =>
      X := 1;
end Precision_Missing_Others_Handler_Clean;
