procedure Precision_Address_Clause_Size_Clean is
   type Byte is range 0 .. 255;
   for Byte'Size use 8;
   X : Byte := 0;
begin
   X := X + 1;
end Precision_Address_Clause_Size_Clean;
