package body Verification_Composite_Membership with SPARK_Mode is

   procedure Normalize (X : in out GF) is
   begin
      X := (others => 0);
      X (2) := 7;
      pragma Assert (X in Normal_GF);
   end Normalize;

   procedure Build (D : out Product; V : I64) is
   begin
      D := (0 => V, 1 => 3, others => -5);
      pragma Assert (D in Product);
   end Build;

   procedure Order (R : in out Pair) is
   begin
      R.B := R.B + 1;
      pragma Assert (R in Pair);
   end Order;

end Verification_Composite_Membership;
