package body Verification_Loop_Predicates with SPARK_Mode is

   --  A loop summarized by its invariant.
   procedure Fill (C : in out Ctx; N : Natural) is
      Count : Natural := 0;
   begin
      while Count < N loop
         pragma Loop_Invariant (Count < N);
         if C.Len < C.Rate / 8 then
            C.Len := C.Len + 1;
         end if;
         Count := Count + 1;
      end loop;
      pragma Assert (C.Len <= 200);
   end Fill;

   --  A loop without an invariant: the head joins the ways into it.
   procedure Fill_Unbounded (C : in out Ctx; N : Natural) is
      Count : Natural := 0;
   begin
      while Count < N loop
         pragma Assert (C.Len * 8 <= C.Rate);
         if C.Len < C.Rate / 8 then
            C.Len := C.Len + 1;
         end if;
         Count := Count + 1;
      end loop;
      pragma Assert (C.Len <= 200);
   end Fill_Unbounded;

end Verification_Loop_Predicates;
