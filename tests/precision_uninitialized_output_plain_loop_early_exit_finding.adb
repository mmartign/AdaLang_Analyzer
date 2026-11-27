--  At the shape of the loop-exit regression (FP-183): a plain loop that
--  can be left before the write does not set the out parameter. Must fire.
procedure Precision_Uninitialized_Output_Plain_Loop_Early_Exit_Finding is
   procedure Wait (Ready : Boolean; Ok : out Boolean) is
   begin
      loop
         exit when not Ready;
         Ok := True;
         exit;
      end loop;
   end Wait;

   Ok : Boolean;
begin
   Wait (False, Ok);
end Precision_Uninitialized_Output_Plain_Loop_Early_Exit_Finding;
