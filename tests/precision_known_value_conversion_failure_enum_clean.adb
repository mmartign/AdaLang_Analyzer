procedure Precision_Known_Value_Conversion_Failure_Enum_Clean is
   type Color is (Red, Green, Blue);
   C : Color;
begin
   C := Color'Value ("green");
end Precision_Known_Value_Conversion_Failure_Enum_Clean;
