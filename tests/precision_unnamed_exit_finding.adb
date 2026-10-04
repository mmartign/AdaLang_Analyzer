procedure Precision_Unnamed_Exit_Finding is
   I : Integer := 0;
begin
   Count : loop
      I := I + 1;
      exit when I > 10;
   end loop Count;
end Precision_Unnamed_Exit_Finding;
