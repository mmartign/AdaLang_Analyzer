procedure Precision_Known_Enum_Val_Failure_Boundary_Clean is
   type Color is (Red, Green, Blue);
   C : Color;
begin
   C := Color'Val (2);
end Precision_Known_Enum_Val_Failure_Boundary_Clean;
