procedure Precision_Block_Statement_Clean is
   X : Integer := 0;
begin
   for I in 1 .. 2 loop
      X := X + I;
   end loop;
exception
   when Constraint_Error =>
      X := 0;
end Precision_Block_Statement_Clean;
