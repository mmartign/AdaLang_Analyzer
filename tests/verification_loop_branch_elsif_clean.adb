procedure Verification_Loop_Branch_Elsif_Clean
  (X    : Integer;
   Mode : Integer;
   Y    : out Integer)
  with SPARK_Mode,
       Pre  => X <= 2_147_483_641,
       Post => Y = X + 3
is
   I     : Integer := 0;
   Extra : Boolean := False;
begin
   Y := X;
   while I < 3 loop
      pragma Loop_Invariant
        (I >= 0 and then I <= 3 and then Y = X + I);
      pragma Loop_Variant (Decreases => 3 - I);

      if Mode = 0 then
         Extra := True;
      elsif Mode = 1 then
         Extra := False;
      else
         Extra := True;
      end if;

      I := I + 1;
      Y := Y + 1;
   end loop;
end Verification_Loop_Branch_Elsif_Clean;
