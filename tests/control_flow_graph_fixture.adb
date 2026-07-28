procedure Control_Flow_Graph_Fixture
  (Flag : Boolean;
   X    : in out Integer)
is
begin
   if Flag then
      X := X + 1;
   elsif X = 0 then
      raise Constraint_Error;
   else
      X := 1;
   end if;

   while X < 10 loop
      exit when X = 5;
      X := X + 1;
   end loop;

   case X is
      when 10 =>
         X := 0;
      when others =>
         null;
   end case;

   begin
      X := X + 1;
   exception
      when Constraint_Error =>
         X := 0;
   end;

   declare
      Local : Integer := X;
   begin
      Local := 10 / Local;
   exception
      when Constraint_Error =>
         X := 0;
      when others =>
         raise;
   end;

   return;
end Control_Flow_Graph_Fixture;
