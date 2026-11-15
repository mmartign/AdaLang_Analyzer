package body State_Latch with SPARK_Mode,
  Refined_State => (State => (Current, Clock))
is

   procedure Lock with Refined_Global => (In_Out => Current) is
   begin
      Current := Locked;
   end Lock;

   procedure Relock with Refined_Global => (In_Out => Current) is
   begin
      if not Is_Locked then
         Current := Locked;
      end if;
   end Relock;

end State_Latch;
