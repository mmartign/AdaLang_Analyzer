--  Positive regression fixture: each suspicious construct below intentionally
--  exercises one or more bug-finding rules used by run_bug_findings.sh.

procedure Bug_Findings is
   A    : Integer := 1;
   B    : Integer := 2;
   Flag : Boolean := True;
begin
   --  Identity, repeated, and absorbing operations exercise expression rules.
   A := A + 0;
   A := A + 0;
   B := A * 0;

   --  The contradictory condition and duplicate branch bodies are deliberate.
   if Flag and then not Flag then
      A := 1;
   elsif B > 0 then
      A := 2;
   else
      A := 2;
   end if;

   --  A null-only loop is expected to trigger Empty_Loop.
   while Flag loop
      null;
   end loop;

   --  The assignment after goto is intentionally unreachable.
   goto Done;
   B := 3;
   <<Done>>
   null;
end Bug_Findings;
