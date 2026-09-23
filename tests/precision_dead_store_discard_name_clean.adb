procedure Precision_Dead_Store_Discard_Name_Clean (Seed : Integer) is
   Dummy   : Integer;
   Ignored : Boolean;

   procedure Probe (Value : Integer; Success : out Boolean) is
   begin
      Success := Value > 0;
   end Probe;
begin
   Dummy := Seed * 2;
   Probe (Seed, Success => Ignored);
end Precision_Dead_Store_Discard_Name_Clean;
