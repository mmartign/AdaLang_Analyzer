procedure Verification_Loop_Variant_Succ
  with SPARK_Mode
is
   I : Integer := 0;
begin
   while I < 10 loop
      pragma Loop_Invariant (I >= 0 and then I <= 10);
      pragma Loop_Variant (Increases => I);
      I := Integer'Succ (I);
   end loop;
end Verification_Loop_Variant_Succ;
