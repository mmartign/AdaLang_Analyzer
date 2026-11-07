--  The objects with relaxed initialization of
--  verification_relaxed_initialization where a part read may have no
--  value: a relaxed parameter, which comes with parts that may have none
--  (FP-140), an object given a relaxed value whole (FP-140), a local with
--  one element written; and what does not say the whole object has a value
--  in every part: X'Initialized of a part, in an "or", after a copy of a
--  relaxed value.
package Verification_Mutation_Relaxed_Initialization
  with SPARK_Mode
is
   type Arr is array (1 .. 4) of Integer;
   type Rec is record
      C : Arr;
      D : Integer;
   end record;

   function Relaxed_In (Carried : Arr) return Integer
     with Relaxed_Initialization => Carried;
   procedure Copied (Dest : out Arr; Src : Arr; Value : out Integer)
     with Relaxed_Initialization => (Dest, Src);
   function Partial return Integer;
   procedure Partial_Assert;
   procedure Fill_Bad (Unfilled : out Arr; From : Arr)
     with Relaxed_Initialization => (Unfilled, From),
          Post => Unfilled'Initialized;
   function Pre_Or (Either : Arr; Flag : Boolean) return Integer
     with Relaxed_Initialization => Either, Pre => Either'Initialized or Flag;
   function Pre_Element (Front : Arr) return Integer
     with Relaxed_Initialization => Front, Pre => Front (1)'Initialized;
   function Pre_Component (Holder : Rec) return Integer
     with Relaxed_Initialization => Holder, Pre => Holder.C'Initialized;
end Verification_Mutation_Relaxed_Initialization;
