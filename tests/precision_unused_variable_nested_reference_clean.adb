procedure Precision_Unused_Variable_Nested_Reference_Clean is
   Counter : Integer := 0;

   procedure Increment is
   begin
      Counter := Counter + 1;
   end Increment;
begin
   Increment;
end Precision_Unused_Variable_Nested_Reference_Clean;
