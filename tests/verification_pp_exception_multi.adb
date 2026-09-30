--  Proof-path evidence: exception sub-boundary with several named handlers.
--  The normal path past a multi-raise chain keeps its branch facts, and a
--  handler obligation that follows from the precondition alone still proves;
--  branch facts never leak into a handler, so a handler assertion that
--  depends on which raise was taken stays Unproved.
procedure Verification_PP_Exception_Multi
  (X : Integer;
   Sink : out Integer)
with SPARK_Mode,
     Pre => X in 0 .. 10
is
begin
   Sink := 0;
   begin
      if X > 3 then
         raise Constraint_Error;
      elsif X > 1 then
         raise Program_Error;
      end if;
      pragma Assert (X <= 1);
      Sink := X + 2;
   exception
      when Constraint_Error =>
         pragma Assert (X < 2);
         Sink := 1;
      when Program_Error =>
         Sink := X - 1;
      when others =>
         Sink := 2;
   end;
end Verification_PP_Exception_Multi;
