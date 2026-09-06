--  FP-065 regression: a "pragma Assert (False)" reached only through a
--  conditional whose guard the analyzer cannot evaluate is not a *definite*
--  assertion failure -- whether the point is reached at all is unknown (here
--  it depends on the caller's Flag; more subtly, an earlier statement on the
--  path in may itself always raise, which the flow domain does not model).
--  The obligation must stay unproved, never definite-error. A straight-line
--  "pragma Assert (False)" still reports a definite error -- see
--  tests/proof_assertion_findings.adb and tests/verification_vc_error.adb.
--  Found on AdaCore SPARK testsuite unit W316-007__string_multidim via
--  benchmarks/spark_testsuite/.
procedure Verification_Assert_False_Guarded (Flag : Boolean)
  with SPARK_Mode
is
begin
   if Flag then
      pragma Assert (False);
   end if;
end Verification_Assert_False_Guarded;
