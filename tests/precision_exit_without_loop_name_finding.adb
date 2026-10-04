procedure Precision_Exit_Without_Loop_Name_Finding is
   Total : Integer := 0;
begin
   loop
      Total := Total + 1;
      exit when Total > 5;
   end loop;
end Precision_Exit_Without_Loop_Name_Finding;
