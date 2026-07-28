procedure Verification_Array_Index_Clean
  (Index  : Integer;
   Result : out Integer)
  with SPARK_Mode,
       Pre  => Index >= 1 and then Index <= 5,
       Post => Result = Index
is
   type Values is array (1 .. 5) of Integer;
   V : constant Values := (1, 2, 3, 4, 5);
begin
   Result := V (Index);
end Verification_Array_Index_Clean;
