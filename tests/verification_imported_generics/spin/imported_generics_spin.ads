--  Seeded defect: Spin, given for Param_Irreflexive, never returns.
--  GNATprove 16.1.0: "aspect Always_Terminates on "Irreflexive" could be
--  incorrect, call to "Spin" might be nonterminating".
with Imported_Maps;
with Imported_Vectors;
package Imported_Generics_Spin with SPARK_Mode is
   type Item is record
      N : Integer := 0;
   end record;
   function "<" (L, R : Item) return Boolean is (L.N < R.N);
   procedure Spin (X : Item) with Global => null;
   package Item_Vectors is new Imported_Vectors (Item);
   package Sorting is new Item_Vectors.Generic_Sorting
     ("<" => "<", Lt_Irreflexive => Spin);
   package Item_Maps is new Imported_Maps (Item, Key_Reflexive => Spin);
end Imported_Generics_Spin;
