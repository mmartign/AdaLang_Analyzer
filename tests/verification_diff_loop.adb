procedure Verification_Diff_Loop
  (Start  : Integer;
   Result : out Integer)
  with SPARK_Mode,
       Pre  => Start <= Integer'Last - 3,
       Post => Result = Start + 3
is
   Count : Integer := 0;
begin
   Result := Start;
   while Count < 3 loop
      pragma Loop_Invariant
        (Count >= 0 and then Count <= 3 and then
         Result = Start + Count);
      pragma Loop_Variant (Decreases => 3 - Count);
      Count := Count + 1;
      Result := Result + 1;
   end loop;
end Verification_Diff_Loop;
