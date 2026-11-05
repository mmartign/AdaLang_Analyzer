--  Seeded defects for the bounds of an array an object is declared with:
--  each claim below is false, and must never be proved.
package Verification_Mutation_Array_Values with SPARK_Mode is
   type Index is range 0 .. 63;
   type Bytes is array (Index range <>) of Integer;
   subtype Bytes_24 is Bytes (0 .. 23);

   procedure Empty_Left (Text : String) with Pre => Text'First = 5;
   procedure Formal_Left (Text : String);
   procedure Variable_Bound (N : Bytes_24; I : Index) with Pre => I <= 20;
   procedure Slice_First (N : Bytes_24);
end Verification_Mutation_Array_Values;
