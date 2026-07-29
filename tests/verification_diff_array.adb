procedure Verification_Diff_Array
  (Index  : Integer;
   Result : out Integer)
  with SPARK_Mode,
       Pre  => Index >= 1 and then Index <= 4,
       Post => Result >= 10 and then Result <= 40
is
   type Value_Array is array (1 .. 4) of Integer;
   Values : constant Value_Array := (10, 20, 30, 40);
begin
   Result := Values (Index);
end Verification_Diff_Array;
