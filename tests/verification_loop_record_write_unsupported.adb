procedure Verification_Loop_Record_Write_Unsupported
  (X : Integer)
  with SPARK_Mode
is
   type Pair is record
      A : Integer;
      B : Integer;
   end record;
   P : Pair := (A => 0, B => 0);
   I : Integer := 0;
begin
   while I < 3 loop
      pragma Loop_Invariant (I >= 0 and then I <= 3 and then P.A = 0);
      pragma Loop_Variant (Decreases => 3 - I);

      P.A := P.A + 1;

      I := I + 1;
   end loop;
end Verification_Loop_Record_Write_Unsupported;
