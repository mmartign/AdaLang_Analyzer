--  Positive regression fixture for the flow-sensitive constant-propagation
--  pass (Interpret_Subprogram_Flow): every finding below is only reachable
--  by tracking a value across statements, not from literal-only evaluation.

procedure Flow_Findings (Selector : Integer; P : Integer; N : Positive) is
   Divisor : Integer := 5;
   Result  : Integer;
   Joined  : Integer := 1;
   Flag    : Boolean := False;
begin
   Divisor := 0;
   Result := 10 / Divisor;

   if Divisor = 0 then
      Result := Result + 1;
   end if;

   --  A declare block seeds its own local declarations the same way a
   --  subprogram body does.
   declare
      Local : Integer := 0;
   begin
      Result := 20 / Local;
   end;

   --  Both alternatives agree on Joined's value, so it survives the join
   --  across the case statement even though Selector isn't known.
   case Selector is
      when 0 =>
         Joined := 0;
      when others =>
         Joined := 0;
   end case;

   if Joined = 0 then
      Result := Result + 2;
   end if;

   --  Flag is only known to be True by tracking it flow-sensitively; a
   --  literal-only evaluation of the condition below sees just an
   --  identifier and stays silent.
   Flag := True;

   if Flag then
      Result := Result + 3;
   end if;

   --  Selector2 is known to be 5, so Interpret_Case's selector narrowing
   --  picks "when 5 =>" alone rather than joining it with "when others =>",
   --  and Divisor2 survives the case known as 0.
   declare
      Selector2 : Integer := 5;
      Divisor2  : Integer := 1;
   begin
      case Selector2 is
         when 5 =>
            Divisor2 := 0;
         when others =>
            Divisor2 := 2;
      end case;

      Result := 10 / Divisor2;
   end;

   --  An "if" expression whose condition resolves via flow tracking:
   --  Divisor3 is known to be 0 here, so the expression's value is known
   --  to be 0 too, without a full constant-folding evaluator.
   declare
      Divisor3 : Integer := 3;
   begin
      Divisor3 := 0;
      Result := 10 / (if Divisor3 = 0 then 0 else Divisor3);
   end;

   --  Range narrowing: P's exact value is never known, but "P > 0" pins a
   --  lower bound on P's tracked range for the rest of the then-branch, so
   --  the nested condition below is provably true without seeing a
   --  literal or an exact assignment.
   if P > 0 then
      if P >= 1 then
         Result := Result + 4;
      end if;
   end if;

   --  For-loop control-variable bounds: I's range is seeded from the
   --  loop's own "1 .. N" bounds, so "I > 0" is provably true on every
   --  iteration even though I's exact value changes each pass.
   for I in 1 .. N loop
      if I > 0 then
         Result := Result + 5;
      end if;
   end loop;
end Flow_Findings;
