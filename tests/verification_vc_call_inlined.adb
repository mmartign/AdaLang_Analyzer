procedure Verification_VC_Call_Inlined (X_In : Integer) is
   function Double (Value : Integer) return Integer is (Value + Value);
   X : Integer := X_In;
begin
   pragma Assume (X >= 0 and then X <= 100);
   pragma Assert (Double (X) >= 0);
end Verification_VC_Call_Inlined;
