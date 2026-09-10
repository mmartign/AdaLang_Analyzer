--  Proof-path evidence: exception sub-boundary. A straight-line scalar
--  obligation reached before any raise, in a subprogram that also carries an
--  exception handler, still proves. The obligation guarded behind a raise /
--  handler edge is left Unsupported, never Proved_Safe.
procedure Verification_PP_Exception_Clean
  (X : Integer;
   Sink : out Integer)
with SPARK_Mode,
     Pre => X in 0 .. 10
is
begin
   Sink := 0;
   pragma Assert (X >= 0);
   Sink := X + 1;

   begin
      if X > 3 then
         raise Constraint_Error;
      end if;
      Sink := X + 2;
   exception
      when others =>
         pragma Assert (X > 3);
         Sink := 0;
   end;
end Verification_PP_Exception_Clean;
