procedure Uninitialized_Read_Clean is
   procedure Initialize (Value : out Integer) is
   begin
      Value := 5;
   end Initialize;

   procedure Assign_Before_Read is
      X : Integer;
   begin
      Initialize (X);
      X := X + 1;
   end Assign_Before_Read;
begin
   Assign_Before_Read;
end Uninitialized_Read_Clean;
