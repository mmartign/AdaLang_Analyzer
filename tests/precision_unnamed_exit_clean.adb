procedure Precision_Unnamed_Exit_Clean is
   I : Integer := 0;
begin
   Count : loop
      I := I + 1;
      exit Count when I > 10;
   end loop Count;

   loop
      I := I - 1;
      exit when I < 0;
   end loop;
end Precision_Unnamed_Exit_Clean;
