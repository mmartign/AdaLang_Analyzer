procedure Verification_Loop_Branch_Case_Nested_If_Unsupported
  (X    : Integer;
   Mode : Integer;
   Y    : out Integer)
  with SPARK_Mode,
       Pre  => X <= 2_147_483_641
is
   I     : Integer := 0;
   Extra : Integer := 0;
begin
   Y := X;
   while I < 3 loop
      pragma Loop_Invariant
        (I >= 0 and then I <= 3 and then Y = X + I and then Extra >= 0);
      pragma Loop_Variant (Decreases => 3 - I);

      case Mode is
         when 0 =>
            if Mode = 2 then
               Extra := Extra - 1;
            else
               Extra := Extra + 1;
            end if;
         when others =>
            Extra := Extra + 1;
      end case;

      I := I + 1;
      Y := Y + 1;
   end loop;
end Verification_Loop_Branch_Case_Nested_If_Unsupported;
