--  Positive regression fixture for the flow-sensitive constant-propagation
--  pass (Interpret_Subprogram_Flow): every finding below is only reachable
--  by tracking a value across statements, not from literal-only evaluation.

procedure Flow_Findings (Selector : Integer) is
   Divisor : Integer := 5;
   Result  : Integer;
   Joined  : Integer := 1;
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
end Flow_Findings;
