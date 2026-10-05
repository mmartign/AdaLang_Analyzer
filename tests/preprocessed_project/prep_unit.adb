procedure Prep_Unit (Value : in out Integer) is
begin
#if MODE = "demo" then
   goto Finish;
#else
   goto Finish;
#end if;
   <<Finish>>
   Value := 0;
end Prep_Unit;
