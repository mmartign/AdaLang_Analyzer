procedure Precision_Outer_Loop_Exit_Finding is
   Total : Integer := 0;
begin
   Outer : for I in 1 .. 3 loop
      Inner : for J in 1 .. 3 loop
         Total := Total + I * J;
         exit Outer when Total > 5;
      end loop Inner;
   end loop Outer;
end Precision_Outer_Loop_Exit_Finding;
