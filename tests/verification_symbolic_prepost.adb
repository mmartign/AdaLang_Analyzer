procedure Verification_Symbolic_Prepost
  (X      : Integer;
   Y      : Integer;
   Result : out Integer)
  with SPARK_Mode,
       Pre  => X = Y,
       Post => Result = Y
is
begin
   Result := X;
end Verification_Symbolic_Prepost;
