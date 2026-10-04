procedure Precision_Exit_From_Conditional_Loop_Finding is
   Total : Integer := 0;
begin
   for I in 1 .. 10 loop
      exit when Total > 5;
      Total := Total + I;
   end loop;
end Precision_Exit_From_Conditional_Loop_Finding;
