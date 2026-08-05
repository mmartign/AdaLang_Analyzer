procedure Precision_Self_Assignment_Rename_Guard is
   A       : Integer := 1;
   A_Alias : Integer renames A;
begin
   A_Alias := A;
end Precision_Self_Assignment_Rename_Guard;
