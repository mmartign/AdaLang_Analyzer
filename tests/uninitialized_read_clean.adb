procedure Uninitialized_Read_Clean is
   procedure Assign_Before_Read is
      X : Integer;
   begin
      X := 5;
      X := X + 1;
   end Assign_Before_Read;
begin
   Assign_Before_Read;
end Uninitialized_Read_Clean;
