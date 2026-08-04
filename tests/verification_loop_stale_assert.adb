procedure Verification_Loop_Stale_Assert (Arg : Positive) is
   Val : Integer := 0;
begin
   for I in 1 .. Arg loop
      Val := 5;
   end loop;
   pragma Assert (Val <= 2);
end Verification_Loop_Stale_Assert;
