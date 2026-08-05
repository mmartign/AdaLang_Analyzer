procedure Precision_Infinite_Loop_Guard is
   I : Integer := 0;
begin
   while True loop
      I := I + 1;
   end loop;
end Precision_Infinite_Loop_Guard;
