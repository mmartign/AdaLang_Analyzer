procedure Precision_Requeue_Call_Clean is
   procedure Requeue_Handler is
   begin
      null;
   end Requeue_Handler;
begin
   Requeue_Handler;
end Precision_Requeue_Call_Clean;
