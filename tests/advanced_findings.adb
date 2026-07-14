--  Positive fixture for data-flow, case analysis, loop, exception, boolean,
--  shadowing, unused-parameter, and complexity checks.
procedure Advanced_Findings
  (Unused : Integer;
   Used   : Integer)
is
   X    : Integer := 0;
   Y    : Integer := 0;
   Flag : Boolean := True;

   procedure Nested is
      X : Integer := 0;
   begin
      X := X + 1;
   end Nested;
begin
   declare
      X : Integer := Used;
   begin
      X := X + 1;
   end;

   X := 1;
   X := 2;
   Y := 3;

   if Used > 0 and then Used > 0 then
      Flag := not (not Flag);
   elsif Used = 1 then
      Nested;
   end if;

   case Used is
      when 1 .. 5 =>
         X := Used;
      when 3 .. 4 =>
         X := Used + 1;
      when others =>
         X := 0;
   end case;

   loop
      X := X + 1;
   end loop;
exception
   when others =>
      null;
end Advanced_Findings;
