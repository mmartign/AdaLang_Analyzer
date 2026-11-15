package body Verification_Mutation_Loop_Predicates with SPARK_Mode is

   procedure Fill (C : in out Ctx; N : Natural) is
      Count : Natural := 0;
   begin
      while Count < N loop
         if C.Len < C.Rate / 8 then
            C.Len := C.Len + 1;
         end if;
         Count := Count + 1;
      end loop;
      pragma Assert (C.Len <= 100);
   end Fill;

   procedure Fill_Plain (C : in out Plain; N : Natural) is
      Count : Natural := 0;
   begin
      while Count < N loop
         C.Len := C.Len + 1;
         Count := Count + 1;
      end loop;
      pragma Assert (C.Len <= 200);
   end Fill_Plain;

end Verification_Mutation_Loop_Predicates;
