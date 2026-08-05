procedure Precision_Attribute_Size_Clean is
   type Root is tagged null record;
   Item_Size : constant Integer := Root'Size;
begin
   null;
end Precision_Attribute_Size_Clean;
