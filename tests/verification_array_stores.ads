--  A write to an element of an array gives the array a value whose
--  contents are those of before with the element at that index, and an
--  aggregate, a copy or 'Update gives it the contents they say. Every claim
--  here holds; verification_mutation_array_stores has those that do not.
package Verification_Array_Stores
  with SPARK_Mode
is
   type I64 is range -2 ** 63 .. 2 ** 63 - 1;
   type Index is range 0 .. 63;
   type Wides is array (Index) of I64;
   type Flags is array (Index) of Boolean;
   subtype Small is I64 range 0 .. 100;
   type Rec is record
      A : Wides;
      N : I64;
   end record;
   function Opaque (V : I64) return I64 with Import;

   procedure Read_Back (A1 : in out Wides; I : Index; S : out Small);
   procedure Known_Back (A2 : in out Wides; S : out Small);
   procedure Kept_Other (A3 : in out Wides; J, K : Index; S : out Small)
     with Pre => (for all I in Index => A3 (I) in 0 .. 100);
   procedure Increment (A4 : in out Wides; I : Index; S : out Small)
     with Pre => A4 (I) in 0 .. 50;
   procedure Swap (A5 : in out Wides; I, J, K : Index; S : out Small)
     with Pre => (for all L in Index => A5 (L) in 0 .. 100);
   procedure In_Record (R6 : in out Rec; J, K : Index; S : out Small)
     with Pre => (for all I in Index => R6.A (I) in 0 .. 100);
   procedure Flag (F7 : in out Flags; J : Index);
   procedure Opaque_Value (A8 : in out Wides; J, K : Index; S : out Small)
     with Pre => J /= K and then (for all I in Index => A8 (I) in 0 .. 100);
   procedure Old_Kept (A9 : in out Wides; J, K : Index)
     with Pre => J /= K, Post => A9 (K) = A9'Old (K);
   procedure Post_Inc (B1 : in out Wides; I : Index)
     with Pre => B1 (I) in 0 .. 50, Post => B1 (I) in 1 .. 51;
   type T4 is array (1 .. 4) of I64;
   type Arr is array (Integer range <>) of I64;

   procedure Others_Zero (G1 : out Wides; K : Index; S : out Small);
   procedure Declared (K : Index; S : out Small);
   procedure Positional (K : Integer; S : out Small) with Pre => K in 1 .. 4;
   procedure Named_Others (G4 : out Wides; K : Index; S : out Small);
   procedure Named_Cover (K : Integer; S : out Small) with Pre => K in 1 .. 4;
   procedure Copy (G6 : out Wides; Y6 : Wides; K : Index; S : out Small)
     with Pre => (for all I in Index => Y6 (I) in 0 .. 100);
   procedure Update (G7 : in out Wides; J, K : Index; S : out Small)
     with Pre => (for all I in Index => G7 (I) in 0 .. 100);
   procedure Flag_Others (F9 : out Flags; K : Index);
   procedure Ranged (H1 : out Wides; K : Index; S : out Small);
   procedure Dynamic_Choice (H2 : out Wides; J : Index; S : out Small);
   procedure Self (H3 : in out Wides; K : Index; S : out Small)
     with Pre => H3 (0) in 0 .. 50;
   procedure Same_Bounds (K : Integer; S : out Small) with Pre => K in 1 .. 4;
end Verification_Array_Stores;
