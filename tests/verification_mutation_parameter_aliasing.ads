--  What verification_parameter_aliasing proves, where it does not hold or
--  is not known: elements at indexes that are not static, slices whose
--  bounds may meet. GNATprove 16.1.0 reports each pair as possibly
--  aliased.
package Verification_Mutation_Parameter_Aliasing with SPARK_Mode is

   type Bytes is array (Natural range <>) of Integer;

   type Ctx is record
      A : Bytes (0 .. 15);
      N : Natural;
   end record;

   type Grid is array (0 .. 3, 0 .. 3) of Integer;

   procedure Copy (Dst : in out Bytes; Src : Bytes)
     with Pre => Dst'Length = Src'Length;

   procedure Swap (X, Y : in out Integer);

   procedure Dynamic_Elements (G : in out Grid; I, J : Natural)
     with Pre => I <= 3 and then J <= 3 and then I /= J;

   procedure Meeting_Slices (C : in out Ctx; K : Natural)
     with Pre => K <= 8;

end Verification_Mutation_Parameter_Aliasing;
