--  Seeded defect: the "<" that Generic_Sorting takes by <> reads Counter.
--  GNATprove 16.1.0: ""Counter" must be listed in the Global aspect of
--  "Lt"".
with Imported_Vectors;
package Imported_Generics_Counter with SPARK_Mode is
   Counter : Integer := 0;
   type Item is record
      N : Integer := 0;
   end record;
   function "<" (L, R : Item) return Boolean with Global => Counter;
   package Item_Vectors is new Imported_Vectors (Item);
   package Sorting is new Item_Vectors.Generic_Sorting;
end Imported_Generics_Counter;
