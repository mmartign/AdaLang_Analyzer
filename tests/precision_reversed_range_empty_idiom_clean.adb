procedure Precision_Reversed_Range_Empty_Idiom_Clean is
   type Arr is array (Integer range <>) of Integer;
   Empty : constant Arr := (1 .. 0 => <>);
begin
   null;
end Precision_Reversed_Range_Empty_Idiom_Clean;
