procedure Precision_Empty_If_Body_Pragma_Assert_Clean is
   X : Integer := 1;
begin
   if X > 0 then
      pragma Assert (False);
   end if;
end Precision_Empty_If_Body_Pragma_Assert_Clean;
