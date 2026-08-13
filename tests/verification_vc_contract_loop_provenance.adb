procedure Verification_VC_Contract_Loop_Provenance (X : in out Integer)
  with Post => X ** 2 >= 0
is
   procedure Require_Square (Value : Integer)
     with Pre => Value ** 2 >= 0
   is
   begin
      null;
   end Require_Square;
begin
   Require_Square (X);
   while X < 0 loop
      pragma Loop_Invariant (X ** 2 >= 0);
      X := X + 1;
   end loop;
end Verification_VC_Contract_Loop_Provenance;
