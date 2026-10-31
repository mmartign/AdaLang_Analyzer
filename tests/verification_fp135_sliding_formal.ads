--  FP-135: a formal of a constrained array subtype has the bounds of that
--  subtype and its actual slides to them, but an element of the formal was
--  read as the element of the actual with the same index. X (1) is A (0)
--  below, so that no claim of the Bad_ subprograms follows, by each of the
--  three ways a formal came to stand for its actual: reading the body of
--  the function, taking a fact from it, and giving the callee what is known
--  of the object. The last three lines of the body are the same reading
--  with the very subtype, or with a formal that takes the actual's bounds,
--  where nothing slides.
package Verification_FP135_Sliding_Formal
  with SPARK_Mode
is
   type Cells is array (Integer range <>) of Integer;
   subtype From_One is Cells (1 .. 3);
   subtype From_Zero is Cells (0 .. 2);

   function First_Of (X : From_One) return Integer is (X (1));
   function Starts_At_Twenty (X : From_One) return Boolean is (X (1) = 20);
   procedure Needs_Twenty (X : From_One) with Pre => X (1) = 20;
   procedure Set_Twenty (X : in out From_One) with Post => X (1) = 20;
   function Own_First (X : Cells) return Integer
   is (X (X'First + 1)) with Pre => X'First < X'Last;

   procedure Bad_Inlined (Slid : From_Zero);
   procedure Bad_Assumed (Slid : From_Zero);
   procedure Bad_Called (Slid : From_Zero);
   procedure Bad_After_Call (Slid : in out From_Zero);

   procedure Same_Subtype_Inlined (A : From_One);
   procedure Same_Subtype_Called (A : From_One);
   procedure Own_Bounds (A : From_Zero);
end Verification_FP135_Sliding_Formal;
