--  Mutations of verification_contract_reach, each a claim that does not
--  hold: a generic subprogram whose precondition gives the range of its
--  parameter, not that it is even; a component whose predicate allows
--  Low = High; a component whose type has no predicate; a value that needs
--  five bits; a renaming whose formals are named in another order; a power
--  of a modular type that wraps to 0.
package Verification_Mutation_Contract_Reach with SPARK_Mode is

   subtype Small is Integer range 0 .. 100;

   function Half (X : Small) return Small is (X / 2)
     with Pre => X mod 2 = 0;

   generic
      with procedure Log (V : Integer);
   procedure Generic_Any (X : Integer) with Pre => X in 0 .. 100;

   type Loose_Pair is record
      Low, High : Integer;
   end record
     with Dynamic_Predicate => Loose_Pair.Low <= Loose_Pair.High;

   type Plain_Pair is record
      Low, High : Integer;
   end record;

   type Holder is record
      L : Loose_Pair;
      P : Plain_Pair;
   end record;

   function Loose_Spread (H : Holder) return Positive
     with Pre => H.L.Low >= 0 and then H.L.High <= 1_000;

   function Plain_Spread (H : Holder) return Positive
     with Pre => H.P.Low >= 0 and then H.P.High <= 1_000;

   type Base_Integer is range 0 .. 2 ** 63 - 1;

   function Fits_Into (V : Base_Integer; Bits : Natural) return Boolean is
     (if Bits < Base_Integer'Size then V < 2 ** Bits);

   function Fits (V : Base_Integer; Bits : Natural) return Boolean
     renames Fits_Into;

   type Five_Bits is range 0 .. 16;

   procedure Store (V : Base_Integer) with Pre => Fits (V, 4);

   procedure Store_Wide (N : Five_Bits);

   function Minus (A, B : Integer) return Integer is (A - B)
     with Pre => A in 0 .. 100 and then B in 0 .. 100;

   function Swapped (B, A : Integer) return Integer renames Minus;

   procedure Need_Positive (X : Integer) with Pre => X > 0;

   procedure Swap_Call;

   type Octet is mod 256;

   function Power (N : Natural) return Octet is (2 ** N)
     with Pre => N <= 8;

   procedure Need_Nonzero (X : Octet) with Pre => X /= 0;

   procedure Wrap_Call;

end Verification_Mutation_Contract_Reach;
