procedure Precision_Unconditional_Exit_Finding is
   Total : Integer := 0;
begin
   loop
      Total := Total + 1;
      if Total > 5 then
         exit;
      end if;
   end loop;
end Precision_Unconditional_Exit_Finding;
