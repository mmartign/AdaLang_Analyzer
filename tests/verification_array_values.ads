--  An array given to an array subtype -- the operand of a conversion, the
--  initial value of an object, an assigned value -- has a length to check
--  and, where it is a slice, bounds; never the range a scalar has. The
--  checks of the slices below are proved, and none is a range check of the
--  array as a value.
package Verification_Array_Values with SPARK_Mode is
   type Index is range 0 .. 63;
   type Bytes is array (Index range <>) of Integer;
   subtype Bytes_16 is Bytes (0 .. 15);
   subtype Bytes_24 is Bytes (0 .. 23);

   procedure Take (B : Bytes_16);
   procedure Converted (N : Bytes_24);
   procedure Declared (N : Bytes_24);
   procedure Assigned (N : Bytes_24; Out_B : out Bytes_16);

   --  An object declared with a concatenation starts where its left
   --  operand does: a string literal that is not empty, a character, an
   --  'Image.
   procedure Concatenated (V : Integer; Text : String; Out_S : out String)
     with Pre => Out_S'First = 1 and then Out_S'Length = 40
                 and then Text'Length <= 10;
end Verification_Array_Values;
