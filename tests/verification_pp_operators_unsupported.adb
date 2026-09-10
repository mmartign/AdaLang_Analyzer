--  Proof-path evidence: operator sub-boundary edge. A reflexive comparison
--  proves; exponentiation stays Unproved with 'unsupported-operator'
--  provenance rather than becoming proof evidence.
procedure Verification_PP_Operators_Unsupported (X : Integer)
with SPARK_Mode
is
begin
   pragma Assert (X = X);
   pragma Assert (X ** 2 >= 0);
end Verification_PP_Operators_Unsupported;
