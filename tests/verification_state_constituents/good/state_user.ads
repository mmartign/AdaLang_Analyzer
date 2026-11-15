with State_Latch;
package State_User with SPARK_Mode is
   procedure Need (B : Boolean) with Global => null, Pre => B;
   procedure Run with Global => (In_Out => State_Latch.State);
end State_User;
