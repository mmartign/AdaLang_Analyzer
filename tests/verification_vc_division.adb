procedure Verification_VC_Division (X_In, Y_In : Integer) is
   X : Integer := X_In;
   Y : Integer := Y_In;
begin
   pragma Assume (Y >= 1 and then Y <= 100);
   pragma Assert (X mod Y >= 0);
   pragma Assert (X mod Y < Y);
   pragma Assume (X >= 0 and then X <= 1000);
   pragma Assert (X rem Y >= 0);
end Verification_VC_Division;
