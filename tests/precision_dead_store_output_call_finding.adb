procedure Precision_Dead_Store_Output_Call_Finding
  (Seed : Integer; Result : out Integer)
is
   Scratch : Integer;

   procedure Fill (Value : out Integer) is
   begin
      Value := Seed;
   end Fill;
begin
   Result := Seed + 1;
   Fill (Scratch);
end Precision_Dead_Store_Output_Call_Finding;
