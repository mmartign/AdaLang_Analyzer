procedure Verification_VC_Quantified is
begin
   pragma Assert (for all I in 1 .. 10 => I >= 1);
   pragma Assert (for some I in 1 .. 10 => I = 7);
end Verification_VC_Quantified;
