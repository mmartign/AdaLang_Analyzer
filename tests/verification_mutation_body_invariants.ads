--  The invariants of verification_body_invariants with what makes them
--  wrong: false on the first iteration, or after the last but one.
package Verification_Mutation_Body_Invariants
  with SPARK_Mode
is
   procedure False_On_Entry;
   procedure False_At_The_End;
end Verification_Mutation_Body_Invariants;
