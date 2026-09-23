procedure Precision_Dead_Store_Status_Finding (Seed : Integer) is
   Status : Boolean;

   procedure Probe (Value : Integer; Success : out Boolean) is
   begin
      Success := Value > 0;
   end Probe;
begin
   Probe (Seed, Success => Status);
end Precision_Dead_Store_Status_Finding;
