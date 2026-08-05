procedure Precision_Handler_Order_Others_First_Guard is
begin
   null;
exception
   when others =>
      null;
   when Constraint_Error =>
      null;
end Precision_Handler_Order_Others_First_Guard;
