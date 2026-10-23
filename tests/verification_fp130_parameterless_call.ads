package Verification_FP130_Parameterless_Call with SPARK_Mode => On is

   G : Integer := 0;

   procedure Bump
     with Global => (In_Out => G), Pre => G < 1_000, Post => G = G'Old + 1;

   procedure Check_G
     with Global => (Input => G), Pre => G < 1_000;

   procedure Many_Bumps;
   procedure Many_Bumps_Invariant;
   procedure Many_Checks;
   procedure Too_Late;

end Verification_FP130_Parameterless_Call;
