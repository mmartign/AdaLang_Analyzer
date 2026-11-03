--  The loops of verification_array_loops with what makes them wrong: an
--  invariant that claims one element too many, a frame that a write ahead
--  breaks, X'Loop_Entry of a value the loop changes or of an earlier entry,
--  an array written by a call or through a renaming, a read after the loop
--  of an element it wrote, X'Old after a loop, a range that may be empty, an
--  exit statement, a statement after the invariant, an invariant that is not
--  preserved.
package Verification_Mutation_Array_Loops
  with SPARK_Mode
is
   type I32 is range -2 ** 31 .. 2 ** 31 - 1;
   type Index is range 0 .. 15;
   type Arr is array (Index) of I32;
   subtype Small is I32 range 0 .. 100;

   --  B1: invariant claims one element too many
   procedure Zero_Bad (A : in out Arr);
   --  B2: frame invariant wrong: loop writes A (I + 1) ahead
   procedure Frame_Bad (A : in out Arr; S : out Small)
     with Pre => (for all K in Index => A (K) in Small);
   --  B3: Loop_Entry frame claims all elements unchanged
   procedure Entry_Bad (A : in out Arr);
   --  B4: array written through a call inside the loop
   procedure Call_Bad (A : in out Arr; S : out Small)
     with Pre => (for all K in Index => A (K) in Small);
   procedure Set (A : in out Arr; I : Index);
   --  B5: read after loop of an element the loop wrote past Small
   procedure After_Bad (A : in out Arr; S : out Small)
     with Pre => (for all K in Index => A (K) in Small);
   --  B6: non-leading invariant claims the wrong range
   procedure Cut_Bad (A : Arr; R : out Arr)
     with Pre => (for all K in Index => A (K) in 0 .. 2000);
   --  B7: alias through renaming inside the loop
   procedure Ren_Bad (A : in out Arr; S : out Small)
     with Pre => (for all K in Index => A (K) in Small);
   --  B8: entry mark must not survive the loop head: X'Old vs X
   procedure Old_Bad_S (X : in out Small)
     with Post => X = X'Old;
   --  B9: same for an array element
   procedure Old_Bad_A (A : in out Arr)
     with Pre => (for all K in Index => A (K) in Small),
          Post => A (3) = A'Old (3);
   --  B11: inner 'Loop_Entry is of each entry, not of the first
   procedure Nested_Bad (A : in out Arr);
   --  B12: scalar 'Loop_Entry of a value the loop changes
   procedure Scalar_Bad (X : in out Small);
   --  B13: range may be empty: no last iteration
   procedure Empty_Bad (N : Index; X : out I32) with Post => X >= 1;
   --  B14: exit when leaves early
   procedure Early_Bad (A : Arr; X : out I32) with Post => X >= 15;
   --  B15: invariant followed by a statement that changes X
   procedure After_Inv_Bad (X : out I32) with Post => X = 14;
   --  B16: reverse loop ends at the first value
   procedure Reverse_Bad (X : out I32) with Post => X = 15;
   --  B17: leading invariant not preserved
   procedure Unproved_Inv_Bad (X : out I32) with Post => X = 0;
end Verification_Mutation_Array_Loops;
