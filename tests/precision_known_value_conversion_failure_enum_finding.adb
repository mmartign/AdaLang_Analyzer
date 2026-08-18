procedure Precision_Known_Value_Conversion_Failure_Enum_Finding is
   type Color is (Red, Green, Blue);
   C : Color;
begin
   C := Color'Value ("Reed");
end Precision_Known_Value_Conversion_Failure_Enum_Finding;
