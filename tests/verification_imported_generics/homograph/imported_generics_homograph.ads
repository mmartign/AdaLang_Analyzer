--  Seeded defect: the "<" that Generic_Sorting takes by <> is
--  Imported_Generics_Ops."<", the only one visible here, which reads
--  Counter; not the predefined "<" of Small. GNATprove 16.1.0: ""Counter"
--  must be listed in the Global aspect of "Lt"".
with Imported_Generics_Small;
with Imported_Generics_Ops; use Imported_Generics_Ops;
with Imported_Vectors;
package Imported_Generics_Homograph with SPARK_Mode is
   package Small_Vectors is new Imported_Vectors
     (Imported_Generics_Small.Small);
   package Sorting is new Small_Vectors.Generic_Sorting;
end Imported_Generics_Homograph;
