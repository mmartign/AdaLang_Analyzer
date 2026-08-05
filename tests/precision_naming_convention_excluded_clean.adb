procedure Precision_Naming_Convention_Excluded_Clean is
   type Color is (R, G, B);
   Chosen : Color := R;
begin
   for I in 1 .. 3 loop
      Chosen := Color'Val ((Color'Pos (Chosen) + I) mod 3);
   end loop;
end Precision_Naming_Convention_Excluded_Clean;
