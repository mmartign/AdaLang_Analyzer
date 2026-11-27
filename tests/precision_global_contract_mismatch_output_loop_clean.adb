--  Precision regression for Global_Contract_Mismatch (FP-189, tokeneer's
--  TISMain): an Output global written by a call in a plain loop, which
--  goes round at least once, before anything in it can leave the loop,
--  and read after that call. Must not fire.
procedure Precision_Global_Contract_Mismatch_Output_Loop_Clean
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
            Tick;
            exit when Current > 0;
         end loop;
      end Run;
   end Clock;
begin
   Clock.Run;
end Precision_Global_Contract_Mismatch_Output_Loop_Clean;
