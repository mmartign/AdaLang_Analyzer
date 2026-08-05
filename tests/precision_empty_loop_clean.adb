procedure Precision_Empty_Loop_Clean is
   Total : Integer := 0;
begin
   for I in 1 .. 3 loop
      Total := Total + I;
   end loop;
end Precision_Empty_Loop_Clean;
