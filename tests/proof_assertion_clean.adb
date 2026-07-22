procedure Proof_Assertion_Clean (X : Integer) is
   Y : Integer := X;
begin
   pragma Assume (Y > 0);
   pragma Assert (Y >= 1);

   Y := 4;
   pragma Check (Assertion, Y = 4);
end Proof_Assertion_Clean;
