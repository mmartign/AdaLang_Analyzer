procedure Verification_Loop_Variant_Wrong_Direction
  with SPARK_Mode
is
   I : Integer := 0;
begin
   while I < 3 loop
      pragma Loop_Invariant (I >= 0 and then I <= 3);
      pragma Loop_Variant (Decreases => I);
      I := I + 1;
   end loop;
end Verification_Loop_Variant_Wrong_Direction;
