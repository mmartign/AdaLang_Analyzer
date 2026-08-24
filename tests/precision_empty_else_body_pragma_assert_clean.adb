procedure Precision_Empty_Else_Body_Pragma_Assert_Clean is
   X : Integer := 1;
   Y : Integer := 0;
begin
   if X > 0 then
      Y := 1;
   else
      pragma Assert (False);
   end if;
end Precision_Empty_Else_Body_Pragma_Assert_Clean;
