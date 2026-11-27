--  Precision regression for Global_Contract_Mismatch (FP-190, SPARK
--  testsuite S530-019): an Output global written in a for loop over a
--  static range of one value, after an exit that leaves the loop before
--  the write, and read after the write. The path through the exit does not
--  read it. Must not fire.
procedure Precision_Global_Contract_Mismatch_Output_Exit_Clean
  with SPARK_Mode
is
   package Store with Abstract_State => State,
     Initializes => State
   is
      procedure Fill (Status : out Natural) with Global => (Output => State);
   end Store;

   package body Store with Refined_State => (State => Current) is
      Current : Natural := 0;

      procedure Check (Status : out Natural) with Global => null is
      begin
         Status := 0;
      end Check;

      procedure Use_Value (Value : Natural) with Global => null is
      begin
         null;
      end Use_Value;

      procedure Fill (Status : out Natural)
        with Refined_Global => (Output => Current)
      is
      begin
         Main_Body :
         for Unused in 1 .. 1 loop
            Check (Status);
            if Status /= 0 then
               exit Main_Body;
            end if;
            Current := 1;
            Use_Value (Current);
         end loop Main_Body;
      end Fill;
   end Store;

   Status : Natural;
begin
   Store.Fill (Status);
end Precision_Global_Contract_Mismatch_Output_Exit_Clean;
