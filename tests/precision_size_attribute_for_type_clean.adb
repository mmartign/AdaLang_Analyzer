procedure Precision_Size_Attribute_For_Type_Clean is
   type Small is range 0 .. 15;
   for Small'Size use 8;
   Value : constant Small := 3;
   Bits  : constant Integer := Value'Size;
begin
   pragma Assert (Bits > 0);
end Precision_Size_Attribute_For_Type_Clean;
