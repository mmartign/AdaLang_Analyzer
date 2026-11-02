--  The invariants of verification_body_invariants with what makes them
--  wrong: false on the first iteration, or after the last but one, and
--  progress invariants of a loop cut where they stand that the first
--  iteration does not bring, or one iteration does not keep.
package Verification_Mutation_Body_Invariants
  with SPARK_Mode
is
   procedure False_On_Entry;
   procedure False_At_The_End;
   procedure Wrong_Start;
   procedure Wrong_Step;
end Verification_Mutation_Body_Invariants;
