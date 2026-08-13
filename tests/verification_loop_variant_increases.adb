procedure Verification_Loop_Variant_Increases
  with SPARK_Mode
is
   I : Integer := 0;
begin
   while I < 10 loop
      pragma Loop_Invariant (I >= 0 and then I <= 10);
      pragma Loop_Variant (Increases => I);
      I := I + 1;
   end loop;
end Verification_Loop_Variant_Increases;
