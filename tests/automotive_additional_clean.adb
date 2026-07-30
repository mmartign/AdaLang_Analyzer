procedure Automotive_Additional_Clean is
   subtype Ascending is Integer range 1 .. 10;
   Value : Ascending := 1;
begin
   if Value < Ascending'Last then
      Value := Value + 1;
   end if;
end Automotive_Additional_Clean;
