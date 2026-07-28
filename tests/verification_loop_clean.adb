procedure Verification_Loop_Clean
  with SPARK_Mode
is
   I : Integer := 0;
begin
   while I < 3 loop
      pragma Loop_Invariant (I >= 0);
      pragma Loop_Variant (Decreases => 3 - I);
      I := I + 1;
   end loop;

   pragma Assert (I >= 3);
end Verification_Loop_Clean;
