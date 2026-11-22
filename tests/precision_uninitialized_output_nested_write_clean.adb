--  An out parameter that a nested procedure writes, as an up-level object,
--  is given its value when the procedure calls it (apdf's Image_ref,
--  FP-168): Uninitialized_Output must not fire.
procedure Precision_Uninitialized_Output_Nested_Write_Clean
  (Name : String; Index : out Positive)
is
   procedure Insert (N : String) is
   begin
      if N'Length > 3 then
         Index := N'Length;
      else
         Index := 1;
      end if;
   end Insert;
begin
   Insert (Name);
end Precision_Uninitialized_Output_Nested_Write_Clean;
