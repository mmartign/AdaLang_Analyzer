--  The arrays of verification_relaxed_elements where an element read, or
--  an X'Initialized, is of an element that may have no value: one past
--  the elements written, past a slice written, past a slice passed to an
--  out parameter, past the range of a loop invariant or of a
--  precondition; one written on one way of an "if" only, at another index;
--  and the elements of an array given a relaxed value whole, or passed to
--  a relaxed out parameter that says nothing on return, which may leave it
--  with none. GNATprove refutes each, or cannot prove it.
package Verification_Mutation_Relaxed_Elements
  with SPARK_Mode
is
   type Arr is array (1 .. 4) of Integer;
   type Bytes is array (Natural range <>) of Integer;
   subtype Bytes_2 is Bytes (0 .. 1);

   procedure Fill_Two (Pair : out Bytes_2) with Global => null;
   procedure Leave (Left : out Arr)
     with Global => null, Relaxed_Initialization => Left;

   procedure Past_Elements (Gappy : out Arr)
     with Relaxed_Initialization => Gappy;
   procedure Past_Slice (Short_Band : out Arr)
     with Relaxed_Initialization => Short_Band;
   procedure Past_Actual (Short_Strip : out Bytes)
     with Relaxed_Initialization => Short_Strip,
          Pre => Short_Strip'First = 0 and then Short_Strip'Last = 3;
   procedure Past_Loop (Short_Lane : out Arr)
     with Relaxed_Initialization => Short_Lane;
   function Past_Range (Short_Range : Arr; Upto : Natural) return Boolean
   is (for all K in 1 .. Upto => Short_Range (K) > 0)
     with Relaxed_Initialization => Short_Range,
          Pre => Upto <= 4 and then
                 (for all K in 2 .. Upto => Short_Range (K)'Initialized);
   procedure One_Branch (Forked : out Arr; Flag : Boolean)
     with Relaxed_Initialization => Forked;
   procedure Other_Index (Moved : out Arr; Where, Read_At : Positive;
                          Value : out Integer)
     with Relaxed_Initialization => Moved,
          Pre => Where <= 4 and then Read_At <= 4;
   procedure Reassigned (Replaced : out Arr; Source : Arr)
     with Relaxed_Initialization => (Replaced, Source);
   procedure Left_By_Call (Dropped : out Arr)
     with Relaxed_Initialization => Dropped;
end Verification_Mutation_Relaxed_Elements;
