procedure Precision_Expanded_Loop_Exit_Name_Finding is
   Total : Integer := 0;
begin
   Count : loop
      Total := Total + 1;
      exit Precision_Expanded_Loop_Exit_Name_Finding.Count when Total > 5;
   end loop Count;
end Precision_Expanded_Loop_Exit_Name_Finding;
