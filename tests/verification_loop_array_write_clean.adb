procedure Verification_Loop_Array_Write_Clean
  (X : Integer;
   Y : out Integer)
  with SPARK_Mode,
       Pre  => X <= 2_147_483_641,
       Post => Y = X + 3
is
   type Buffer is array (1 .. 3) of Integer;
   Values : Buffer := (others => 0);
   I      : Integer := 0;
begin
   Y := X;
   while I < 3 loop
      pragma Loop_Invariant
        (I >= 0 and then I <= 3 and then Y = X + I);
      pragma Loop_Variant (Decreases => 3 - I);

      Values (I + 1) := 0;

      I := I + 1;
      Y := Y + 1;
   end loop;
end Verification_Loop_Array_Write_Clean;
