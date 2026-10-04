procedure Precision_Exit_From_Conditional_Loop_Clean is
   Total : Integer := 0;
begin
   loop
      exit when Total > 5;
      Total := Total + 1;
   end loop;
end Precision_Exit_From_Conditional_Loop_Clean;
