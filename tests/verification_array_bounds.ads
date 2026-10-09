--  What is known of the bounds of an array whatever they are, and of the
--  result of an operation of a type the compiler chooses the base range of.
--
--  Each bound of an array is a value of the type of its index, and both
--  belong to the index subtype unless the array is null. A formal of an
--  unconstrained array type has the bounds of its actual: those a
--  declaration fixes for an object, those of the subtype of a function
--  result, of a conversion or of a qualified expression, and for a string
--  literal the first value of the index subtype and its length. A result
--  within the part of its type's base range that the language guarantees
--  does not overflow.
package Verification_Array_Bounds with SPARK_Mode => On is

   type Bytes is array (Natural range <>) of Integer;

   subtype Index is Positive range 1 .. 150;
   subtype Line is String (Index);
   Blank : constant Line := Line'(others => ' ');

   type Wide is range -1_000 .. 1_000;
   subtype Half is Wide range 0 .. 400;

   procedure Log (Text : String) with Pre => Text'First = 1;

   function Made return Line;

   procedure From_Constant;
   procedure From_Literal;
   procedure From_Local;
   procedure From_Result;
   procedure From_Conversion (Other : String)
     with Pre => Other'Length = 150;
   procedure Span (Data : Bytes; R : out Integer);
   procedure Sum (Left, Right : Half; R : out Wide);

end Verification_Array_Bounds;
