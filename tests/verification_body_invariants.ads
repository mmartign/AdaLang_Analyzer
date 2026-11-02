--  A loop invariant that does not lead its loop is checked in the state
--  where it stands, which is that of every iteration, the first included,
--  and assumes nothing of it: what that state proves holds on entry and
--  after every iteration. Every claim here holds.
--  verification_mutation_body_invariants has those that do not.
package Verification_Body_Invariants
  with SPARK_Mode
is
   procedure Constant_Value;
   procedure Bounded_Value;
   procedure Related_Value (A : Integer) with Pre => A in 0 .. 100;
end Verification_Body_Invariants;
