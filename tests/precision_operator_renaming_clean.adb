procedure Precision_Operator_Renaming_Clean is
   function Sum (L, R : Integer) return Integer is (L + R);
   function Add (L, R : Integer) return Integer renames Sum;
   X : constant Integer := Add (1, 2);
begin
   pragma Assert (X = 3);
end Precision_Operator_Renaming_Clean;
