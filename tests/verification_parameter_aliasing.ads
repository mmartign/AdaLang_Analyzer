--  Non-aliasing of actual parameters (SPARK RM 6.4.2): two actuals that
--  name parts of one object, one of them written, denote parts that cannot
--  overlap -- different components, elements at static indexes that
--  differ, slices with static bounds that do not meet. GNATprove 16.1.0
--  proves each non-aliasing check.
package Verification_Parameter_Aliasing with SPARK_Mode is

   type Bytes is array (Natural range <>) of Integer;

   type Ctx is record
      A : Bytes (0 .. 15);
      B : Bytes (0 .. 15);
      N : Natural;
   end record;

   type Grid is array (0 .. 3, 0 .. 3) of Integer;

   procedure Copy (Dst : in out Bytes; Src : Bytes)
     with Pre => Dst'Length = Src'Length;

   procedure Swap (X, Y : in out Integer);

   procedure Components (C : in out Ctx);

   procedure Elements (G : in out Grid);

   procedure Slices (C : in out Ctx);

end Verification_Parameter_Aliasing;
