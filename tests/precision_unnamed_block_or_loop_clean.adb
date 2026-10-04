procedure Precision_Unnamed_Block_Or_Loop_Clean is
   Total : Integer := 0;
begin
   Outer : for I in 1 .. 3 loop
      Inner : for J in 1 .. 3 loop
         Total := Total + I * J;
      end loop Inner;
   end loop Outer;

   for K in 1 .. 3 loop
      Total := Total + K;
   end loop;

   Scratch : declare
      Copy : constant Integer := Total;
   begin
      Total := Copy + 1;
   end Scratch;
end Precision_Unnamed_Block_Or_Loop_Clean;
