package body Verification_Mutation_Composite_Membership with SPARK_Mode is

   procedure Normalize (X : in out GF) is
   begin
      X := (others => 0);
      X (3) := -1;
      pragma Assert (X in Normal_GF);
   end Normalize;

   procedure Build (D : out GF; V : I64) is
   begin
      D := (0 => V, 1 => 3, others => -5);
      pragma Assert (D in Product);
   end Build;

end Verification_Mutation_Composite_Membership;
