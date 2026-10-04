procedure Precision_Enumeration_Representation_Clause_Finding is
   type Colour is (Red, Green);
   for Colour use (Red => 1, Green => 4);
   C : constant Colour := Red;
begin
   pragma Assert (C = Red);
end Precision_Enumeration_Representation_Clause_Finding;
