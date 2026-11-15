--  The membership of a record or an array object in its own type or in a
--  subtype that adds only a predicate is the predicate of that object.
--  GNATprove 16.1.0 proves every assertion.
package Verification_Composite_Membership with SPARK_Mode is

   type I64 is range -2 ** 63 .. 2 ** 63 - 1;

   subtype Limb is I64 range 0 .. 65_535;

   type Index is range 0 .. 3;

   type GF is array (Index) of I64;

   subtype Normal_GF is GF
     with Dynamic_Predicate =>
       (for all I in Index => Normal_GF (I) in Limb);

   type Product is array (Index) of I64
     with Dynamic_Predicate => Product (0) >= 0 and Product (0) <= 100
                               and Product (1) in Limb;

   type Pair is record
      A, B : I64;
   end record
     with Dynamic_Predicate => A <= B;

   procedure Normalize (X : in out GF);

   procedure Build (D : out Product; V : I64) with Pre => V in 0 .. 50;

   procedure Order (R : in out Pair) with Pre => R.B < 1_000;

end Verification_Composite_Membership;
