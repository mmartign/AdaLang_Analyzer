procedure Verification_VC_Unsupported
  (X : Integer;
   Y : Integer)
  with SPARK_Mode
is
begin
   pragma Assert (X / Y = X);
end Verification_VC_Unsupported;
