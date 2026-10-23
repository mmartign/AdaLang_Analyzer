package body Verification_FP130_Parameterless_Call with SPARK_Mode => On is

   procedure Bump is
   begin
      G := G + 1;
   end Bump;

   procedure Check_G is
   begin
      null;
   end Check_G;

   --  A call with no actual in parentheses, in a loop: the precondition
   --  holds on the first iterations, and fails on the 1001st, G being
   --  1000 then. It was decided on the first visit only.
   procedure Many_Bumps is
      C : Natural := 0;
   begin
      G := 0;
      while C < 2_000 loop
         Bump;
         C := C + 1;
      end loop;
   end Many_Bumps;

   procedure Many_Bumps_Invariant is
      C : Natural := 0;
   begin
      G := 0;
      while C < 2_000 loop
         pragma Loop_Invariant (C <= 2_000);
         Bump;
         C := C + 1;
      end loop;
   end Many_Bumps_Invariant;

   --  A call in a loop that writes nothing its precondition reads: the
   --  precondition holds at the fixed point, and is proved there.
   procedure Many_Checks is
      C : Natural := 0;
   begin
      G := 5;
      while C < 2_000 loop
         Check_G;
         C := C + 1;
      end loop;
   end Many_Checks;

   --  Decided where it is, the precondition of such a call that fails is
   --  a definite error.
   procedure Too_Late is
   begin
      G := 5_000;
      Bump;
   end Too_Late;

end Verification_FP130_Parameterless_Call;
