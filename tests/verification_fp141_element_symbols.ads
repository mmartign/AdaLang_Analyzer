--  FP-141: the value written to an element of an array, or to the whole
--  array, was translated in the state before the write, where a read of an
--  element there could give the element its first symbol; the state after
--  the write did not know that symbol was the value before, and took it
--  for the value of the element after it. "L (2) := L (2) + 1" then made
--  L (2) equal to itself plus one, from which anything follows. Each
--  procedure asserts what the write makes false, and what it makes true.
package Verification_FP141_Element_Symbols
  with SPARK_Mode
is
   type Arr is array (1 .. 4) of Integer range 0 .. 1000;
   type Box is record
      C : Arr;
   end record;

   procedure Bumped;
   procedure Swapped;
   procedure In_Record;
   procedure Other_Index (I : Integer) with Pre => I in 1 .. 4;
   procedure Kept;
end Verification_FP141_Element_Symbols;
