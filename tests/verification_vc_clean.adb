procedure Verification_VC_Clean
  (X    : Integer;
   Flag : Boolean)
  with SPARK_Mode
is
begin
   pragma Assert (X = X);
   pragma Assert (X - X = 0);
   pragma Assert (Flag or else not Flag);
end Verification_VC_Clean;
