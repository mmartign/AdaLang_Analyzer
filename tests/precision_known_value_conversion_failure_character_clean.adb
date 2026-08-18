procedure Precision_Known_Value_Conversion_Failure_Character_Clean is
   C : Character;
begin
   C := Character'Value ("not a character literal at all");
end Precision_Known_Value_Conversion_Failure_Character_Clean;
