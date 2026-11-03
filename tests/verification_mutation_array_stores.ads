--  The writes and values of verification_array_stores with what makes them
--  wrong: a later write at the same index, a read at an index that may be
--  the one written, an index or a value with no term, another array, an
--  aggregate or a copy that slides to the bounds of the target.
package Verification_Mutation_Array_Stores
  with SPARK_Mode
is
   type I64 is range -2 ** 63 .. 2 ** 63 - 1;
   type Index is range 0 .. 63;
   type Wides is array (Index) of I64;
   subtype Small is I64 range 0 .. 100;
   function Pick (I : Index) return Index with Import;

   procedure Last_Wins (C1 : in out Wides; J : Index; S : out Small);
   procedure Maybe_Same (C2 : in out Wides; J, K : Index; S : out Small)
     with Pre => (for all I in Index => C2 (I) in 0 .. 100);
   procedure Self_Read (C3 : in out Wides; I, J : Index)
     with Pre => (for all L in Index => C3 (L) in 0 .. 100);
   procedure Hidden_Index (C5 : in out Wides; J, K : Index; S : out Small)
     with Pre => (for all I in Index => C5 (I) in 0 .. 100);
   procedure Other_Array (C6, D6 : in out Wides; I : Index; S : out Small);
   procedure Old_Changed (C7 : in out Wides; J, K : Index)
     with Post => C7 (K) = C7'Old (K);
   procedure Post_Wrong (C8 : in out Wides; I : Index)
     with Pre => C8 (I) in 0 .. 50, Post => C8 (I) in 0 .. 50;
   procedure Swap_Wrong (C9 : in out Wides; I, J : Index)
     with Pre => C9 (I) in 0 .. 100;
   type Arr is array (Integer range <>) of I64;

   procedure Slid_Named (S : out Small);
   procedure Slid_Copy (Yc : Arr; K : Integer; S : out Small)
     with Pre => Yc'First = 0 and then Yc'Last = 3 and then K in 1 .. 3
       and then (for all J in 1 .. 3 => Yc (J) in 0 .. 100);
   procedure Update_Bad (E3 : in out Wides; J : Index; S : out Small);
   procedure Others_Bad (E4 : out Wides; K : Index; S : out Small);
   procedure Dynamic_Bad (E5 : out Wides; J, K : Index; S : out Small);
   procedure Copy_Then_Write
     (E6 : out Wides; Y6 : Wides; K : Index; S : out Small)
     with Pre => (for all I in Index => Y6 (I) in 0 .. 100);
   procedure Copy_Source_Written
     (E7 : out Wides; Y7 : in out Wides; K : Index; S : out Small)
     with Pre => (for all I in Index => Y7 (I) in 0 .. 100);
end Verification_Mutation_Array_Stores;
