--  Negative fixture for the advanced checks. Values are read after writes,
--  case choices are disjoint, and the loop and handler terminate explicitly.
procedure Advanced_Clean
  (Input  : Integer;
   Output : out Integer)
is
   Value : Integer := Input;
begin
   Value := Input + 1;
   Output := Value;

   case Input is
      when 0 .. 4 =>
         Output := Value;
      when 5 .. 9 =>
         Output := Value + 1;
      when others =>
         Output := 0;
   end case;

   loop
      exit when Output >= 0;
   end loop;
exception
   when others =>
      raise;
end Advanced_Clean;
