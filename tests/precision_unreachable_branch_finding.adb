procedure Precision_Unreachable_Branch_Finding is
   X : Integer := 0;
begin
   if False then
      X := 1;
   end if;
end Precision_Unreachable_Branch_Finding;
