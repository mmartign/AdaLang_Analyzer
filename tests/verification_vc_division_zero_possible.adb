procedure Verification_VC_Division_Zero_Possible (X_In, Y_In : Integer) is
   X : Integer := X_In;
   Y : Integer := Y_In;
begin
   pragma Assume (Y >= -5 and then Y <= 5);
   pragma Assert (X mod Y >= 0);
end Verification_VC_Division_Zero_Possible;
