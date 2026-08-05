procedure Precision_New_Call_Clean is
   function New_Value return Integer is
   begin
      return 5;
   end New_Value;

   X : Integer := New_Value;
begin
   X := X + 1;
end Precision_New_Call_Clean;
