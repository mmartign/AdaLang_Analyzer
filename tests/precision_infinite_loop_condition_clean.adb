procedure Precision_Infinite_Loop_Condition_Clean (Done : Boolean) is
   I : Integer := 0;
begin
   while not Done loop
      I := I + 1;
   end loop;
end Precision_Infinite_Loop_Condition_Clean;
