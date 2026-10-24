--  What a contract or a declaration says of objects nothing changes holds
--  all through a loop: the Ok_* subprograms have checks in loop bodies that
--  follow from a precondition on "in" parameters, or from a constant
--  declared ahead of the loop, together with the loop invariant. The Bad_*
--  subprograms have facts that do not hold all through their loop: of a
--  constant the loop declares again each time round, of the parameter of
--  an enclosing loop, of an "in out" parameter the loop changes, and one
--  that holds on one way through the body only.
with Interfaces; use Interfaces;
package Verification_Loop_Standing_Facts
  with SPARK_Mode
is
   subtype Index_Number is Natural range 0 .. Natural'Last - 1;
   type Byte_Array is array (Index_Number range <>) of Unsigned_8;
   type Coord is range 0 .. 4;

   procedure Ok_Linear (Data : Byte_Array; Len : Natural; W : out Unsigned_8)
     with Global => null, Pre => Len <= Data'Length;
   procedure Ok_Division
     (Data : Byte_Array; Bit_Len : Natural; W : out Unsigned_8)
     with Global => null,
          Pre => Bit_Len <= 320 and then (Bit_Len + 7) / 8 <= Data'Length;
   procedure Ok_Constant (Data : Byte_Array; W : out Unsigned_8)
     with Global => null, Pre => Data'Length >= 40;
   procedure Bad_Inner_Constant (W : out Integer)
     with Global => null;
   procedure Bad_Outer_Parameter (W : out Integer)
     with Global => null;
   procedure Bad_In_Out (N : in out Natural; W : out Integer)
     with Global => null, Pre => N <= 10;
   procedure Bad_One_Way (Data : Byte_Array; Len : Natural; W : out Unsigned_8)
     with Global => null;
end Verification_Loop_Standing_Facts;
