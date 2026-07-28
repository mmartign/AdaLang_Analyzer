procedure Verification_Symbolic_Branch
  (X : Integer;
   Y : Integer)
  with SPARK_Mode
is
begin
   if X = Y then
      pragma Assert (X - Y = 0);
   end if;
end Verification_Symbolic_Branch;
