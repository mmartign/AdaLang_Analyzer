procedure Precision_Empty_Then_Body_Guard is
   X : Integer := 1;
   Y : Integer := 0;
begin
   if X > 0 then
      null;
   elsif X < 0 then
      Y := -1;
   end if;
end Precision_Empty_Then_Body_Guard;
