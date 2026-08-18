procedure Precision_Contradictory_Range_Condition_Different_Operand_Clean
  (X : Integer; Y : Integer)
is
begin
   if X > 10 and then Y < 5 then
      null;
   end if;
end Precision_Contradictory_Range_Condition_Different_Operand_Clean;
