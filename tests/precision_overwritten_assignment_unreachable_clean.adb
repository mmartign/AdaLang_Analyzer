procedure Precision_Overwritten_Assignment_Unreachable_Clean
  (Value : out Integer)
is
begin
   Value := 1;
   return;
   Value := 2;
end Precision_Overwritten_Assignment_Unreachable_Clean;
