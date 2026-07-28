procedure Verification_Loop_VC_Broken
  (X : Integer;
   Y : out Integer)
  with SPARK_Mode,
       Pre  => X <= 2_147_483_641,
       Post => Y = X + 3
is
   I : Integer := 0;
begin
   Y := X;
   while I < 3 loop
      pragma Loop_Invariant
        (I >= 0 and then I <= 3 and then Y = X + I);
      I := I + 1;
      Y := Y + 2;
   end loop;
end Verification_Loop_VC_Broken;
