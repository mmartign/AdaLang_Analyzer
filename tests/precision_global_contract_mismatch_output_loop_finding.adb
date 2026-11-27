--  At the shape of the TISMain regression (FP-189): the plain loop reads
--  the Output global before the call that writes it. Must fire.
procedure Precision_Global_Contract_Mismatch_Output_Loop_Finding
  with SPARK_Mode
is
   package Clock with Abstract_State => Time_State,
     Initializes => Time_State
   is
      procedure Tick with Global => (Output => Time_State);
      procedure Run with Global => (Output => Time_State);
   end Clock;

   package body Clock with Refined_State => (Time_State => Current) is
      Current : Natural := 0;

      procedure Tick
        with Refined_Global => (Output => Current)
      is
      begin
         Current := 1;
      end Tick;

      procedure Run
        with Refined_Global => (Output => Current)
      is
      begin
         loop
            exit when Current > 0;
            Tick;
         end loop;
      end Run;
   end Clock;
begin
   Clock.Run;
end Precision_Global_Contract_Mismatch_Output_Loop_Finding;
