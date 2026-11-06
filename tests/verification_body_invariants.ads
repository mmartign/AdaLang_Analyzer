--  A loop invariant that does not lead its loop is checked in the state
--  where it stands, which is that of every iteration, the first included,
--  and assumes nothing of it: what that state proves holds on entry and
--  after every iteration. Otherwise the loop is cut where the invariant
--  stands: each state the loop is entered with brings it there, and from
--  it, one iteration back to it keeps it, the assertions on the way known
--  where they stand. Every claim here holds.
--  verification_mutation_body_invariants has those that do not.
package Verification_Body_Invariants
  with SPARK_Mode
is
   procedure Constant_Value;
   procedure Bounded_Value;
   procedure Related_Value (A : Integer) with Pre => A in 0 .. 100;
   procedure Counted;
   procedure Progress;
   procedure Progress_With_Exit;
   procedure Entered_Again;
   type Values is array (1 .. 10) of Integer;
   procedure Assumed_Step (A : Values);
end Verification_Body_Invariants;
