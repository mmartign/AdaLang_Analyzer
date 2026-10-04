procedure Precision_Expanded_Loop_Exit_Name_Clean is
   Total : Integer := 0;
begin
   Count : loop
      Total := Total + 1;
      exit Count when Total > 5;
   end loop Count;
end Precision_Expanded_Loop_Exit_Name_Clean;
