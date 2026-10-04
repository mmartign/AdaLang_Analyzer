procedure Precision_Size_Attribute_For_Type_Finding is
   type Small is range 0 .. 15;
   Bits : constant Integer := Small'Size;
begin
   pragma Assert (Bits > 0);
end Precision_Size_Attribute_For_Type_Finding;
