package body Verification_Parameter_Aliasing with SPARK_Mode is

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

   procedure Components (C : in out Ctx) is
   begin
      Copy (C.A, C.B);
   end Components;

   procedure Elements (G : in out Grid) is
   begin
      Swap (G (0, 0), G (1, 0));
   end Elements;

   procedure Slices (C : in out Ctx) is
   begin
      Copy (C.A (0 .. 7), C.A (8 .. 15));
   end Slices;

end Verification_Parameter_Aliasing;
