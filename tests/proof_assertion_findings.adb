procedure Proof_Assertion_Findings is
   X : Integer := 0;
begin
   pragma Assert (False);

   X := 3;
   pragma Assert (X = 4);

   pragma Check (Assertion, X < 0);
end Proof_Assertion_Findings;
