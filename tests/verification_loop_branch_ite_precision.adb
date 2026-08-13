procedure Verification_Loop_Branch_Ite_Precision
  (N    : Integer;
   Flag : Boolean;
   C    : out Integer)
  with SPARK_Mode,
       Pre => N >= 0 and then N <= 100
is
   I     : Integer := 0;
   Count : Integer := 0;
begin
   while I < N loop
      pragma Loop_Invariant
        (I >= 0 and then I <= N and then Count >= 0 and then Count <= I);
      pragma Loop_Variant (Decreases => N - I);

      if Flag then
         Count := Count + 1;
      end if;

      I := I + 1;
   end loop;
   C := Count;
end Verification_Loop_Branch_Ite_Precision;
