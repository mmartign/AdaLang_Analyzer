procedure Uninitialized_Read_Attribute_Designator_Guard is
   Last : Integer;
   Bits : Integer;
begin
   --  Excluding an attribute *designator* ("Last" naming the attribute in
   --  "X'Last") must not also exclude a genuine reference used as an
   --  attribute *prefix* ("Last" as the object in "Last'Size"): the
   --  variable itself is still read here, before ever being assigned.
   Bits := Last'Size;
end Uninitialized_Read_Attribute_Designator_Guard;
