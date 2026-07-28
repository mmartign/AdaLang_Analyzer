procedure Verification_VC_Error (X : Integer)
  with SPARK_Mode
is
begin
   pragma Assert (X /= X);
end Verification_VC_Error;
