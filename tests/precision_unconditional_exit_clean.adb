procedure Precision_Unconditional_Exit_Clean is
   Total : Integer := 0;
begin
   loop
      Total := Total + 1;
      exit when Total > 5;
   end loop;
end Precision_Unconditional_Exit_Clean;
