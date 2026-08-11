procedure Verification_VC_Conversion_Modular (X_In : Integer) is
   type Byte is mod 256;
   X : Integer := X_In;
begin
   pragma Assume (X >= 0 and then X <= 100);
   pragma Assert (Integer (Byte (X)) >= 0);
end Verification_VC_Conversion_Modular;
