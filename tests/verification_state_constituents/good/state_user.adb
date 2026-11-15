package body State_User with SPARK_Mode is

   procedure Need (B : Boolean) is null;

   procedure Run is
   begin
      State_Latch.Lock;
      Need (State_Latch.Is_Locked);
      Need (State_Latch.After (State_Latch.Now, State_Latch.Now));
   end Run;

end State_User;
