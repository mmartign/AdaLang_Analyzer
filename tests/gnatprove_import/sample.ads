--  Checks GNATprove and AdaLang agree on, checks only GNATprove proves,
--  a check AdaLang has no obligation for, and checks neither proves:
--  what tests/run_gnatprove_import.sh sets GNATprove's log beside.
package Sample with SPARK_Mode is

   type Vector is array (Positive range <>) of Integer;

   --  Both prove the division.
   function Half (Value : Integer) return Integer is (Value / 2);

   --  Neither proves it.
   function Quotient (Left : Integer; Right : Integer) return Integer is
     (Left / Right);

   --  GNATprove proves the addition from what the precondition says of
   --  every element.
   function Sum_Of_Two (Data : Vector) return Integer is
     (Data (Data'First) + Data (Data'Last))
     with Pre => Data'Length = 2
                 and then (for all Index in Data'Range =>
                             Data (Index) in 0 .. 100);

   --  The assignment has a length check, of which AdaLang raises none.
   procedure Copy (Source : Vector; Target : out Vector)
     with Pre => Source'Length = Target'Length;

   --  A division by zero, whatever a log says.
   procedure Divide_By_Zero (Result : out Integer);

end Sample;
