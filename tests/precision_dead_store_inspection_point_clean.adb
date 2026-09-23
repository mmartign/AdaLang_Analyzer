procedure Precision_Dead_Store_Inspection_Point_Clean
  (Seed : Integer; Result : out Integer)
is
   Secret : Integer;

   procedure Wipe (Value : out Integer) is
   begin
      Value := 0;
      pragma Inspection_Point (Value);
   end Wipe;
begin
   Secret := Seed * 7;
   Result := Secret + 1;
   Wipe (Secret);
end Precision_Dead_Store_Inspection_Point_Clean;
