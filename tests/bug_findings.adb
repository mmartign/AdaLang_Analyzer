procedure Bug_Findings is
   A    : Integer := 1;
   B    : Integer := 2;
   Flag : Boolean := True;
begin
   A := A + 0;
   A := A + 0;
   B := A * 0;

   if Flag and then not Flag then
      A := 1;
   elsif B > 0 then
      A := 2;
   else
      A := 2;
   end if;

   while Flag loop
      null;
   end loop;

   goto Done;
   B := 3;
   <<Done>>
   null;
end Bug_Findings;
