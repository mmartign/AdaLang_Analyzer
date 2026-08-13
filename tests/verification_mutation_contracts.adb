procedure Verification_Mutation_Contracts
  (X : Integer;
   Y : out Integer)
with SPARK_Mode,
     Post => Y /= X
is
   procedure Require_Positive (Value : Integer)
     with Pre => Value > 0
   is
   begin
      null;
   end Require_Positive;
begin
   Require_Positive (0);
   Y := X;
end Verification_Mutation_Contracts;
