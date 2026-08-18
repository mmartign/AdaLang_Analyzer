procedure Precision_Known_Enum_Val_Failure_Dynamic_Clean (N : Integer) is
   type Color is (Red, Green, Blue);
   C : Color;
begin
   C := Color'Val (N);
end Precision_Known_Enum_Val_Failure_Dynamic_Clean;
