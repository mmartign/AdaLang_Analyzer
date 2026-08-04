procedure Verification_Loop_Stale_Precondition (Arg : Positive) is
   procedure Helper (X : Integer)
     with SPARK_Mode, Global => null, Pre => X <= 2
   is
   begin
      null;
   end Helper;
   Val : Integer := 0;
begin
   for I in 1 .. Arg loop
      Val := 5;
   end loop;
   Helper (Val);
end Verification_Loop_Stale_Precondition;
