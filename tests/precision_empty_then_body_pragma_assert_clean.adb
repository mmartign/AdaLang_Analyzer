procedure Precision_Empty_Then_Body_Pragma_Assert_Clean is
   X : Integer := 1;
   Y : Integer := 0;
begin
   if X > 0 then
      pragma Assert (False);
   elsif X < 0 then
      Y := -1;
   end if;
end Precision_Empty_Then_Body_Pragma_Assert_Clean;
