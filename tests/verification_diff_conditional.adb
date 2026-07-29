procedure Verification_Diff_Conditional
  (Input  : Integer;
   Result : out Integer)
  with SPARK_Mode,
       Pre  => Input > Integer'First,
       Post => Result >= 0
is
begin
   if Input >= 0 then
      Result := Input;
   else
      Result := -Input;
   end if;
end Verification_Diff_Conditional;
