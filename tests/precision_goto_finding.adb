procedure Precision_Goto_Finding is
   I : Integer := 0;
begin
   <<Start>>
   I := I + 1;
   if I < 3 then
      goto Start;
   end if;
end Precision_Goto_Finding;
