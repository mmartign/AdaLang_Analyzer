procedure Precision_Unnamed_Block_Or_Loop_Finding is
   Total : Integer := 0;
begin
   for I in 1 .. 3 loop
      for J in 1 .. 3 loop
         Total := Total + I * J;
      end loop;
   end loop;

   declare
      Copy : constant Integer := Total;
   begin
      Total := Copy + 1;
   end;
end Precision_Unnamed_Block_Or_Loop_Finding;
