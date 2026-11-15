--  What verification_composite_membership proves, where it does not hold:
--  an element outside Limb, a first element that may exceed 100. The
--  object of the second is of a type with no predicate, so that nothing
--  is checked, and assumed, where it is assigned.
--  GNATprove 16.1.0 refuses each assertion.
package Verification_Mutation_Composite_Membership with SPARK_Mode is

   type I64 is range -2 ** 63 .. 2 ** 63 - 1;

   subtype Limb is I64 range 0 .. 65_535;

   type Index is range 0 .. 3;

   type GF is array (Index) of I64;

   subtype Normal_GF is GF
     with Dynamic_Predicate =>
       (for all I in Index => Normal_GF (I) in Limb);

   subtype Product is GF
     with Dynamic_Predicate => Product (0) >= 0 and Product (0) <= 100
                               and Product (1) in Limb;

   procedure Normalize (X : in out GF);

   procedure Build (D : out GF; V : I64) with Pre => V in 0 .. 500;

end Verification_Mutation_Composite_Membership;
