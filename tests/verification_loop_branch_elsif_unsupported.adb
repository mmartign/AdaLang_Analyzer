procedure Verification_Loop_Branch_Elsif_Unsupported
  (X : Integer)
  with SPARK_Mode
is
   I : Integer := 0;
   J : Integer := 0;
begin
   while I < 4 loop
      pragma Loop_Invariant (I >= 0 and then I <= 4);
      pragma Loop_Variant (Increases => I);

      if X = 0 then
         J := J + 1;
      elsif X = 1 then
         J := J + 2;
      else
         J := J + 3;
      end if;

      I := I + 1;
   end loop;
end Verification_Loop_Branch_Elsif_Unsupported;
