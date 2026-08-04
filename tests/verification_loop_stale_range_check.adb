procedure Verification_Loop_Stale_Range_Check (Arg : Positive) is
   subtype Small is Integer range 0 .. 10;
   Val       : Small;
   Unrelated : Integer;
begin
   for I in 1 .. Arg loop
      Unrelated := I;
   end loop;
   Val := 999;
end Verification_Loop_Stale_Range_Check;
