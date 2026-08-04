procedure Verification_Loop_Stale_Range (Arg : Positive) is
   subtype Small is Integer range 0 .. 2;
   Val : Integer := 0;
   V2  : Small;
begin
   for I in 1 .. Arg loop
      Val := 5;
   end loop;
   V2 := Val;
end Verification_Loop_Stale_Range;
