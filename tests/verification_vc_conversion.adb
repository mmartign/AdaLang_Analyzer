procedure Verification_VC_Conversion (X_In : Integer) is
   X : Integer := X_In;
begin
   pragma Assume (X >= 10 and then X <= 20);
   pragma Assert (Long_Long_Integer (X) >= 10);
end Verification_VC_Conversion;
