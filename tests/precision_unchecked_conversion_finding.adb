with Ada.Unchecked_Conversion;

procedure Precision_Unchecked_Conversion_Finding is
   function Convert is new Ada.Unchecked_Conversion (Integer, Float);
   Y : Float;
begin
   Y := Convert (0);
end Precision_Unchecked_Conversion_Finding;
