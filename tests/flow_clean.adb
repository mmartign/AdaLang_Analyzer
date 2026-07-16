--  Negative regression fixture for the flow-sensitive constant-propagation
--  pass: cases that could look like flow findings to a naive implementation
--  but must not be reported.

procedure Flow_Clean
  (N : Positive; Selector : Integer; Cond_Param : Boolean;
   P : Integer; Q : Integer)
is
   Divisor        : Integer := 5;
   Unknown        : Integer := N;
   Result         : Integer;
   Joined         : Integer := 1;
   Flag           : Boolean := True;
   Untracked_Flag : Boolean := Cond_Param;
   Local_If       : Integer := (if Selector = 99 then 0 else 1);
begin
   --  A parameter's value is never statically known, so this division must
   --  not be flagged even though Unknown is only ever assigned once.
   Result := 10 / Unknown;

   --  Local_If's condition depends on a parameter, so the whole "if"
   --  expression stays unknown; this division must not be flagged either.
   Result := 10 / Local_If;

   --  A boolean seeded from a parameter is just as unknown as Unknown
   --  above, so this condition must not be reported as constant.
   if Untracked_Flag then
      Result := 3;
   end if;

   --  Divisor is reassigned later in this same loop body, so its pre-loop
   --  value (5) must not be assumed to still hold here on every iteration:
   --  the condition is only true on the first pass.
   for I in 1 .. N loop
      if Divisor = 5 then
         Result := 1;
      end if;
      Divisor := 0;
   end loop;

   --  Same reasoning for a boolean flag rather than an integer: Flag is
   --  reassigned later in this loop body, so its pre-loop value (True)
   --  must not be assumed to still hold on every pass.
   for I in 1 .. N loop
      if Flag then
         Result := 4;
      end if;
      Flag := False;
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

   --  Selector4's known value (7) doesn't match the "when 0" choice, so
   --  Interpret_Case's selector narrowing must pick "when others" here,
   --  not the first-listed alternative: Divisor5 must stay known as 3,
   --  not be wrongly narrowed to the "when 0" branch's 0.
   declare
      Selector4 : Integer := 7;
      Divisor5  : Integer := 3;
   begin
      case Selector4 is
         when 0 =>
            Divisor5 := 0;
         when others =>
            null;
      end case;
      Result := 10 / Divisor5;
   end;

   --  "P > 0" narrows P's own tracked range, but says nothing about the
   --  unrelated variable Q, so this must not be flagged.
   if P > 0 then
      if Q > 0 then
         Result := 6;
      end if;
   end if;

   --  "P > 0" only pins a lower bound of 1 on P, nowhere near enough to
   --  decide this unrelated, much tighter comparison.
   if P > 0 then
      if P > 1000 then
         Result := 7;
      end if;
   end if;

   --  The for loop's own upper bound (N) is a parameter, so nothing pins
   --  I above 1000 either.
   for I in 1 .. N loop
      if I > 1000 then
         Result := 8;
      end if;
   end loop;
end Flow_Clean;
