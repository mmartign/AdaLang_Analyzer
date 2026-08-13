procedure Verification_Mutation_Loop_Initialization
  with SPARK_Mode
is
   I : Integer := 1;
begin
   while I <= 3 loop
      pragma Loop_Invariant (I = 0);
      I := I + 1;
   end loop;
end Verification_Mutation_Loop_Initialization;
