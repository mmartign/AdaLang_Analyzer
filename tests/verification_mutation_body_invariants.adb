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

   --  9 + 0 /= 10 on the first iteration.
   procedure Wrong_Start is
      N : Integer := 10;
      C : Integer := 0;
   begin
      while N > 0 loop
         N := N - 1;
         pragma Loop_Invariant (N + C = 10);
         C := C + 1;
      end loop;
   end Wrong_Start;

   --  True on the first iteration, broken by the step of 2.
   procedure Wrong_Step is
      N : Integer := 10;
      C : Integer := 0;
   begin
      while N > 0 loop
         N := N - 1;
         pragma Loop_Invariant (N + C + 1 = 10);
         C := C + 2;
      end loop;
   end Wrong_Step;
end Verification_Mutation_Body_Invariants;
