procedure Precision_Empty_Elsif_Body_Guard is
   X : Integer := 1;
   Y : Integer := 0;
begin
   if X > 0 then
      Y := 1;
   elsif X < 0 then
      null;
   end if;
end Precision_Empty_Elsif_Body_Guard;
