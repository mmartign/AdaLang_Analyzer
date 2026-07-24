with Ada.Unchecked_Conversion;

procedure Automotive_Policy_Clean is
   function Float_To_Integer is new Ada.Unchecked_Conversion
     (Float, Integer);

   Descriptive_Value : Integer := Float_To_Integer (0.0);
begin
   for I in 1 .. 1 loop
      Descriptive_Value := Descriptive_Value + I;
   end loop;
end Automotive_Policy_Clean;
