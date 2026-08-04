procedure Verification_Loop_Stale_Division (Arg : Positive) is
   Divisor : Integer := 5;
   Result  : Integer;
begin
   for I in 1 .. Arg loop
      Divisor := 0;
   end loop;
   Result := 100 / Divisor;
end Verification_Loop_Stale_Division;
