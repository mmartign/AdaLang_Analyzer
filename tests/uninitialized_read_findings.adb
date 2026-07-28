procedure Uninitialized_Read_Findings is
   procedure Reads_Before_Assignment is
      X : Integer;
      Y : Integer;
   begin
      Y := 0;
      X := X + 1;
   end Reads_Before_Assignment;
begin
   Reads_Before_Assignment;
end Uninitialized_Read_Findings;
