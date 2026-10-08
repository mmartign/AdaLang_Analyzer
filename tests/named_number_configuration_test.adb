--  A test of a named number selects the code for one configuration: it is
--  not a condition that is constant by mistake, and the branch it leaves
--  out is not dead code to report. A condition that is constant as it is
--  written still is one.
procedure Named_Number_Configuration_Test
  (Value : Integer; Result : out Integer)
is
   Buffer_Limit : constant := 0;
begin
   if Buffer_Limit = 0 then
      Result := Value;
   elsif Buffer_Limit > 100 then
      Result := 100;
   else
      Result := Value + Buffer_Limit;
   end if;

   while Buffer_Limit > 0 loop
      Result := Result + 1;
      exit;
   end loop;

   if 1 = 2 then
      Result := 0;
   end if;
end Named_Number_Configuration_Test;
