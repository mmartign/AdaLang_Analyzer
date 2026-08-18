procedure Precision_Known_Enum_Val_Failure_Finding is
   type Color is (Red, Green, Blue);
   C : Color;
begin
   C := Color'Val (5);
end Precision_Known_Enum_Val_Failure_Finding;
