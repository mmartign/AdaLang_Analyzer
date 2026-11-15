package body Verification_Mutation_Parameter_Aliasing with SPARK_Mode is

   procedure Copy (Dst : in out Bytes; Src : Bytes) is
   begin
      Dst := Src;
   end Copy;

   procedure Swap (X, Y : in out Integer) is
      T : constant Integer := X;
   begin
      X := Y;
      Y := T;
   end Swap;

   procedure Dynamic_Elements (G : in out Grid; I, J : Natural) is
   begin
      Swap (G (I, 0), G (J, 0));
   end Dynamic_Elements;

   procedure Meeting_Slices (C : in out Ctx; K : Natural) is
   begin
      Copy (C.A (0 .. 7), C.A (K .. K + 7));
   end Meeting_Slices;

end Verification_Mutation_Parameter_Aliasing;
