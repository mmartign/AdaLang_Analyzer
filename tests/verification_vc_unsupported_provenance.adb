procedure Verification_VC_Unsupported_Provenance (X : Integer) is
   function Square (Value : Integer) return Integer is (Value ** 2);
   function Outer (Value : Integer) return Integer is (Square (Value));
begin
   pragma Assert (X ** 2 >= 0);
   pragma Assert (Square (X) >= 0);
   pragma Assert (Outer (X) >= 0);
end Verification_VC_Unsupported_Provenance;
