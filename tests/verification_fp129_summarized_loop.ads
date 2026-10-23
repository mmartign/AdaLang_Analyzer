package Verification_FP129_Summarized_Loop with SPARK_Mode => On is

   G : Integer := 0;

   procedure Incr (X : in out Integer)
     with Pre => X < 1_000, Post => X = X'Old + 1;

   procedure Bump
     with Global => (In_Out => G), Pre => G < 1_000, Post => G = G'Old + 1;

   procedure By_Call_In_For;
   procedure By_Call_In_While;
   procedure By_Global;
   procedure By_Inner_Loop;

end Verification_FP129_Summarized_Loop;
