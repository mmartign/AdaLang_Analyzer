--  Instances of the generic units of an imported project. GNATprove 16.1.0
--  proves every check in them: the termination of Irreflexive and Lt, their
--  data dependencies, and that of the null procedures the instances take
--  for Lt_Irreflexive, Key_Reflexive and Key_Symmetric.
with Imported_Maps;
with Imported_Vectors;
package Imported_Generics_User with SPARK_Mode is
   type Item is record
      N : Integer := 0;
   end record;
   function "<" (L, R : Item) return Boolean is (L.N < R.N);
   package Item_Vectors is new Imported_Vectors (Item);
   package Sorting is new Item_Vectors.Generic_Sorting ("<" => "<");
   package Item_Maps is new Imported_Maps (Item);

   --  "<" taken by <>: the primitive of Item2, then the predefined "<" of
   --  Integer.
   type Item2 is record
      N : Integer := 0;
   end record;
   function "<" (L, R : Item2) return Boolean is (L.N > R.N);
   package Item2_Vectors is new Imported_Vectors (Item2);
   package Sorting2 is new Item2_Vectors.Generic_Sorting;
   package Int_Vectors is new Imported_Vectors (Integer);
   package Sorting3 is new Int_Vectors.Generic_Sorting;
end Imported_Generics_User;
