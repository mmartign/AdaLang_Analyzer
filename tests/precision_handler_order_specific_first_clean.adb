procedure Precision_Handler_Order_Specific_First_Clean is
begin
   null;
exception
   when Constraint_Error =>
      null;
   when others =>
      null;
end Precision_Handler_Order_Specific_First_Clean;
