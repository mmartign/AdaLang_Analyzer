package body Verification_Mutation_Body_Invariants
  with SPARK_Mode
is
   procedure False_On_Entry is
      X : Integer := 0;
   begin
      for K in 1 .. 10 loop
         X := K;
         pragma Loop_Invariant (X > 1);
      end loop;
   end False_On_Entry;

   procedure False_At_The_End is
      X : Integer := 0;
   begin
      for K in 1 .. 10 loop
         X := K;
         pragma Loop_Invariant (X < 10);
      end loop;
   end False_At_The_End;
end Verification_Mutation_Body_Invariants;
