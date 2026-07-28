procedure Verification_Clean
  (Input  : Integer;
   Result : out Integer)
with
  SPARK_Mode,
  Pre  => Input >= 1 and then Input <= 3,
  Post => Result >= 2 and then Result <= 4
is
begin
   Result := Input + 1;
   pragma Assert (Input /= 0);

   if False then
      Result := 10 / 0;
   end if;
end Verification_Clean;
