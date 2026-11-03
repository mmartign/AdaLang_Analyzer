--  The reads of verification_array_contents with what makes them wrong:
--  the element may have been written since what is known of it was said,
--  by name, through another name, by a call or in a loop, or what is known
--  is of another array, or of the elements of an actual at other indexes
--  than its own.
package Verification_Mutation_Array_Contents
  with SPARK_Mode
is
   type I64 is range -2 ** 63 .. 2 ** 63 - 1;
   type Index is range 0 .. 63;
   type Wides is array (Index) of I64;
   type Arr is array (Integer range <>) of I64;
   subtype Small is I64 range 0 .. 100;
   type Rec is record
      A : Wides;
      N : I64;
   end record;
   subtype Normal is Wides
     with Dynamic_Predicate => (for all I in Index => Normal (I) in 0 .. 100);
   subtype A0 is Arr (0 .. 3)
     with Dynamic_Predicate => (for all I in 1 .. 3 => A0 (I) in 0 .. 100);
   G : Wides := (others => 0);

   procedure Written (Wr : in out Wides; K, J : Index; S : out Small)
     with Pre => (for all I in Index => Wr (I) in 0 .. 100);
   procedure Other (Xo, Yo : Wides; K : Index; S : out Small)
     with Pre => (for all I in Index => Xo (I) in 0 .. 100);
   procedure Looped (Lp : in out Wides; K : Index; S : out Small)
     with Pre => (for all I in Index => Lp (I) in 0 .. 100);
   procedure Fill (Fo : out Wides);
   procedure Filled (Fi : in out Wides; K : Index; S : out Small)
     with Pre => (for all I in Index => Fi (I) in 0 .. 100);
   procedure Post_Bad (Pb : in out Wides; K : Index)
     with Pre => Pb (K) in 0 .. 100, Post => Pb (K) in 0 .. 100;
   procedure Same_Index (Si : in out Wides; K, J : Index; S : out Small)
     with Pre => Si (K) in 0 .. 100;
   procedure Part_Write (Pw : in out Wides; K : Index; S : out Small)
     with Pre => K <= 62 and then (for all I in Index => Pw (I) in 0 .. 100);
   procedure Ren (Rn : in out Wides; K : Index; S : out Small)
     with Pre => (for all I in Index => Rn (I) in 0 .. 100);
   procedure In_Loop (Il : in out Wides; K : Index; S : out Small)
     with Pre => (for all I in Index => Il (I) in 0 .. 100);
   procedure Set200 (V : out I64) with Post => V = 200;
   procedure Out_Element (Oe : in out Wides; K, J : Index; S : out Small)
     with Pre => (for all I in Index => Oe (I) in 0 .. 100);
   procedure Rec_Write (Rw : in out Rec; K, J : Index; S : out Small)
     with Pre => (for all I in Index => Rw.A (I) in 0 .. 100);
   procedure Clobber with Global => (In_Out => G);
   procedure Global_Write (K : Index; S : out Small)
     with Global => (In_Out => G),
          Pre => (for all I in Index => G (I) in 0 .. 100);
   procedure Then_Assert (Ta : in out Wides; K, J : Index)
     with Pre => (for all I in Index => Ta (I) in 0 .. 100);
   procedure Q0 (Y : A0; K : Integer)
     with Pre => K in 0 .. 3 and then Y (K) in 0 .. 100;
   procedure Sliding_Call (Sc : Arr; K : Integer)
     with Pre => Sc'First = 1 and then Sc'Last = 4 and then K in 1 .. 3
       and then (for all J in 1 .. 3 => Sc (J) in 0 .. 100);
   procedure Written_Normal (Wn : in out Normal; K, J : Index; S : out Small);
   procedure Plain (Pl : Wides; K : Index; S : out Small);
end Verification_Mutation_Array_Contents;
