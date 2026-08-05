procedure Precision_Missing_Loop_Variant_Guard is
   I : Integer := 0;
begin
   loop
      pragma Loop_Invariant (I >= 0);
      exit when I = 10;
      I := I + 1;
   end loop;
end Precision_Missing_Loop_Variant_Guard;
