--  An element of an array read at an index whose value is not known is
--  the element at that index of the contents of the array's value: what a
--  quantified precondition, a precondition at that index, a predicate of
--  the array's subtype, or a postcondition with X'Old says of the contents
--  is known of it. Every claim here holds;
--  verification_mutation_array_contents has those that do not.
package Verification_Array_Contents
  with SPARK_Mode
is
   type I64 is range -2 ** 63 .. 2 ** 63 - 1;
   type Index is range 0 .. 63;
   type Wides is array (Index) of I64;
   type Flags is array (Index) of Boolean;
   type Arr is array (Integer range <>) of I64;
   type From_One is array (Integer range 1 .. 8) of I64;
   type M8 is mod 8;
   type By_Mod is array (M8) of I64;
   subtype Small is I64 range 0 .. 100;
   type Rec is record
      A : Wides;
      N : I64;
   end record;
   subtype Normal is Wides
     with Dynamic_Predicate => (for all I in Index => Normal (I) in 0 .. 100);
   subtype Split is Wides
     with Dynamic_Predicate =>
       (Split (0) in 0 .. 50
        and (for all K in Index range 1 .. 63 => Split (K) in 0 .. 100));

   procedure Quantified (Q : Wides; K : Index; S : out Small)
     with Pre => (for all J in Index => Q (J) in 0 .. 100);
   procedure Pointed (P : Wides; K : Index; S : out Small)
     with Pre => P (K) in 0 .. 100;
   procedure Ranged (R : Arr; K : Integer; S : out Small)
     with Pre => K in R'Range
       and then (for all J in R'Range => R (J) in 0 .. 100);
   procedure Shifted (H : Wides; I : Index; S : out Small)
     with Pre => I >= 16 and then (for all J in Index => H (J) in 0 .. 100);
   function Get (G : Wides; K : Index) return I64 is (G (K));
   procedure Through (T : Wides; K : Index; S : out Small)
     with Pre => Get (T, K) in 0 .. 100;
   procedure Kept (E : in out Wides; K, J : Index)
     with Pre => E (K) in 0 .. 100, Post => E'Old (K) in 0 .. 100;
   procedure Large (L : Arr; K : Integer; S : out Small)
     with Pre => L'First = 0 and then L'Last = 999 and then K in 0 .. 999
       and then (for all J in 0 .. 999 => L (J) in 0 .. 100);
   procedure One_Based (O : From_One; K : Integer; S : out Small)
     with Pre => K in 1 .. 8
       and then (for all J in 1 .. 8 => O (J) in 0 .. 100);
   procedure Wrap (M : By_Mod; K : M8; S : out Small)
     with Pre => K in 6 .. 7
       and then (for all J in M8 range 0 .. 1 => M (J) in 0 .. 100);
   procedure Field (F : Rec; K : Index; S : out Small)
     with Pre => (for all I in Index => F.A (I) in 0 .. 100);
   procedure Other_Written (X, Y : in out Wides; K, J : Index; S : out Small)
     with Pre => (for all I in Index => X (I) in 0 .. 100);
   procedure Flagged (Fl : Flags; V : Wides; K : Index; S : out Small)
     with Pre => Fl (K)
       and then (for all I in Index => (if Fl (I) then V (I) in 0 .. 100));
   procedure Asserted (A : Wides; K : Index)
     with Pre => (for all I in Index => A (I) in 0 .. 100);
   procedure Of_Normal (N : Normal; K : Index; S : out Small);
   procedure Known_Normal (Nk : Normal; S : out Small);
   procedure Of_Split (D : Split; K : Index; S : out Small);
   procedure Make (Z : out Normal);
   procedure After_Call (K : Index; S : out Small);
end Verification_Array_Contents;
