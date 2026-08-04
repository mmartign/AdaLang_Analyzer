procedure Verification_Loop_Stale_Overflow (Arg : Positive) is
   X : Integer := 0;
   Y : Integer;
begin
   for I in 1 .. Arg loop
      X := Integer'Last;
   end loop;
   Y := X + 1;
end Verification_Loop_Stale_Overflow;
