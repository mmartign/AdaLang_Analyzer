procedure Verification_Diff_Arithmetic
  (Input  : Integer;
   Result : out Integer)
  with SPARK_Mode,
       Pre  => Input <= Integer'Last - 2,
       Post => Result = Input + 2
is
begin
   Result := Input + 1;
   Result := Result + 1;
end Verification_Diff_Arithmetic;
