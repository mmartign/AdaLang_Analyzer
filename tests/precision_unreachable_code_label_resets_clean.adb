procedure Precision_Unreachable_Code_Label_Resets_Clean is
   X : Integer;
begin
   return;
   <<Skip>>
   X := 1;
end Precision_Unreachable_Code_Label_Resets_Clean;
