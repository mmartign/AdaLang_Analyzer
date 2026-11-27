--  At the shape of the loop-exit regression (FP-183): an exit that names
--  the outer loop leaves it from inside an inner loop, before the write.
--  Must fire.
procedure Precision_Uninitialized_Output_Loop_Outer_Exit_Finding is
   procedure Scan (Stop : Boolean; Ok : out Boolean) is
   begin
      Outer :
      for Try in 1 .. 3 loop
         for I in 1 .. 2 loop
            exit Outer when Stop;
         end loop;
         Ok := True;
      end loop Outer;
   end Scan;

   Ok : Boolean;
begin
   Scan (True, Ok);
end Precision_Uninitialized_Output_Loop_Outer_Exit_Finding;
