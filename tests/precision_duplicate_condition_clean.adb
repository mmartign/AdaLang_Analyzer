procedure Precision_Duplicate_Condition_Clean is
   X, Y, Z : Integer := 1;
begin
   if X > 0 then
      Z := 1;
   elsif Y > 0 then
      Z := 2;
   elsif X < 0 then
      Z := 3;
   end if;
end Precision_Duplicate_Condition_Clean;
