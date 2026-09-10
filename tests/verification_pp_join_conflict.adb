--  Proof-path evidence: join sub-boundary, adversarial. When the two arms of
--  a branch assign a scalar different values, the binding is dropped at the
--  merge and an assertion that would need the arm-local value must not be
--  proved safe.
procedure Verification_PP_Join_Conflict
  (Cond : Boolean;
   Sink : out Integer)
with SPARK_Mode
is
   Y : Integer;
begin
   if Cond then
      Y := 1;
   else
      Y := 2;
   end if;
   pragma Assert (Y = 1);
   Sink := Y;
end Verification_PP_Join_Conflict;
