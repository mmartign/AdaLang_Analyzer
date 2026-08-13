procedure Verification_Loop_Branch_Ite_Cond_Unsupported
  (X : Integer;
   Y : out Integer)
  with SPARK_Mode,
       Pre => X <= 2_147_483_641
is
   type Buffer is array (1 .. 3) of Integer;
   Values : Buffer := (others => 0);
   I      : Integer := 0;
   Extra  : Integer := 0;
begin
   Y := X;
   while I < 3 loop
      pragma Loop_Invariant
        (I >= 0 and then I <= 3 and then Y = X + I and then Extra >= 0);
      pragma Loop_Variant (Decreases => 3 - I);

      if Values (I + 1) > 0 then
         Extra := Extra + 1;
      else
         Extra := Extra - 1;
      end if;

      I := I + 1;
      Y := Y + 1;
   end loop;
end Verification_Loop_Branch_Ite_Cond_Unsupported;
