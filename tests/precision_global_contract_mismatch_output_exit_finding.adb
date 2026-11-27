--  At the shape of the S530-019 regression (FP-190): after the exit, the
--  loop reads the Output global before it writes it. Must fire.
procedure Precision_Global_Contract_Mismatch_Output_Exit_Finding
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
            Use_Value (Current);
            Current := 1;
         end loop Main_Body;
      end Fill;
   end Store;

   Status : Natural;
begin
   Store.Fill (Status);
end Precision_Global_Contract_Mismatch_Output_Exit_Finding;
