procedure Verification_VC_Division_Refuted (X_In : Integer) is
   X : Integer := X_In;
begin
   pragma Assume (X >= 10 and then X <= 12);
   pragma Assert (X mod 3 = 5);
end Verification_VC_Division_Refuted;
