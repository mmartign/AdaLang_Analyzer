--  The conversions of verification_element_ranges with what makes them
--  wrong: the subtype of the components does not fit the target, or the
--  code is not SPARK code, whose data need not be valid.
package Verification_Mutation_Element_Ranges
  with SPARK_Mode
is
   type I64 is range -2 ** 63 .. 2 ** 63 - 1;
   type Byte is mod 2 ** 8;
   type Index is range 0 .. 63;
   type Bytes is array (Index) of Byte;
   type Wides is array (Index) of I64;
   subtype Small is I64 range 0 .. 100;
   subtype Big is I64 range 0 .. 1000;

   procedure Narrow (X : Bytes; K : Index; S : out Small);
   procedure Wide (W : Wides; K : Index; S : out Small);
   procedure Halved (Y : Bytes; K : Index; S : out Small);
   procedure Not_SPARK (N : Bytes; K : Index; S : out Big);
end Verification_Mutation_Element_Ranges;
