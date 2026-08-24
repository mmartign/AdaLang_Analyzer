procedure Precision_Empty_Elsif_Body_Pragma_Assert_Clean is
   X : Integer := 1;
   Y : Integer := 0;
begin
   if X > 0 then
      Y := 1;
   elsif X < 0 then
      pragma Assert (False);
   end if;
end Precision_Empty_Elsif_Body_Pragma_Assert_Clean;
