package body State_Latch with SPARK_Mode,
  Refined_State => (State => (Current, Clock))
is

   procedure Lock with Refined_Global => (Output => Current) is
      Was : constant T := Current;
   begin
      Current := (if Was = Locked then Locked else Locked);
   end Lock;

   procedure Relock with Refined_Global => (In_Out => Current) is
   begin
      if not Is_Locked or else Now.Seconds = 0 then
         Current := Locked;
      end if;
   end Relock;

end State_Latch;
