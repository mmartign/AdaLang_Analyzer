--  Negative regression fixture for the flow-sensitive constant-propagation
--  pass: cases that could look like flow findings to a naive implementation
--  but must not be reported.

procedure Flow_Clean (N : Positive; Selector : Integer) is
   Divisor  : Integer := 5;
   Unknown  : Integer := N;
   Result   : Integer;
   Joined   : Integer := 1;
begin
   --  A parameter's value is never statically known, so this division must
   --  not be flagged even though Unknown is only ever assigned once.
   Result := 10 / Unknown;

   --  Divisor is reassigned later in this same loop body, so its pre-loop
   --  value (5) must not be assumed to still hold here on every iteration:
   --  the condition is only true on the first pass.
   for I in 1 .. N loop
      if Divisor = 5 then
         Result := 1;
      end if;
      Divisor := 0;
   end loop;

   --  A declare block's local variable, seeded from a parameter, is just
   --  as unknown as Unknown above.
   declare
      Local : Integer := Selector;
   begin
      Result := 10 / Local;
   end;

   --  The two case alternatives disagree on Joined's value, so the join
   --  after the case statement must drop it rather than pick either one.
   case Selector is
      when 0 =>
         Joined := 1;
      when others =>
         Joined := 2;
   end case;

   if Joined = 1 then
      Result := 2;
   end if;
end Flow_Clean;
