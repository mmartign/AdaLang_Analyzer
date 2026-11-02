--  In SPARK code an element of an array is a value of the subtype of the
--  array's components, at whatever index it is read: a conversion of it to
--  a subtype that holds that range is safe. Every claim here holds.
--  verification_mutation_element_ranges has those that do not.
package Verification_Element_Ranges
  with SPARK_Mode
is
   type I64 is range -2 ** 63 .. 2 ** 63 - 1;
   type Byte is mod 2 ** 8;
   type Index_64 is range 0 .. 63;
   type Bytes_64 is array (Index_64) of Byte;
   subtype Outer_Limb is I64 range -1000 .. 1000;

   procedure Local_Subtype (X : Bytes_64);
   procedure Outer_Subtype (X : Bytes_64);
end Verification_Element_Ranges;
