procedure Verification_Loop_Stale_Initialization (Arg : Positive)
  with SPARK_Mode
is
   Val : Natural;
begin
   for I in 1 .. Arg loop
      Val := I;
   end loop;
   pragma Assert (Val >= 0);
end Verification_Loop_Stale_Initialization;
