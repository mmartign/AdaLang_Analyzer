procedure Verification_VC_Variant_Leading_Invariant_Order
  with SPARK_Mode
is
   I : Integer := 0;
begin
   while I < 10 loop
      pragma Loop_Variant   (Increases => I);
      pragma Loop_Invariant (I >= 0 and then I <= 10);
      I := I + 1;
   end loop;
end Verification_VC_Variant_Leading_Invariant_Order;
