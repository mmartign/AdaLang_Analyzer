procedure Precision_Operator_Renaming_Finding is
   function Add (L, R : Integer) return Integer renames "+";
   X : constant Integer := Add (1, 2);
begin
   pragma Assert (X = 3);
end Precision_Operator_Renaming_Finding;
