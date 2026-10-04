procedure Precision_Exit_Without_Loop_Name_Clean is
   Total : Integer := 0;
begin
   Count : loop
      Total := Total + 1;
      exit Count when Total > 5;
   end loop Count;
end Precision_Exit_Without_Loop_Name_Clean;
