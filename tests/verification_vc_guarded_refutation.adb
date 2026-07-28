procedure Verification_VC_Guarded_Refutation (X : Integer)
  with SPARK_Mode
is
begin
   --  The mathematical formula is always false, but evaluating X * X may
   --  overflow first. It is therefore not a definite assertion failure.
   pragma Assert (X * X < 0);
end Verification_VC_Guarded_Refutation;
