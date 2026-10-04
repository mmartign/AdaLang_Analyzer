procedure Precision_Enumeration_Representation_Clause_Clean is
   type Colour is (Red, Green);
   for Colour'Size use 8;
   type Pair is record
      First : Colour;
   end record;
   for Pair use record
      First at 0 range 0 .. 7;
   end record;
   P : constant Pair := (First => Red);
begin
   pragma Assert (P.First = Red);
end Precision_Enumeration_Representation_Clause_Clean;
