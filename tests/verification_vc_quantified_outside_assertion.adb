procedure Verification_VC_Quantified_Outside_Assertion (X_In : Integer) is
   X : Integer := X_In;
begin
   pragma Assume (X >= 0 and then X <= 10);
   if (for all I in 1 .. 10 => I >= 1) then
      null;
   end if;
   pragma Assert (X >= 0);
end Verification_VC_Quantified_Outside_Assertion;
