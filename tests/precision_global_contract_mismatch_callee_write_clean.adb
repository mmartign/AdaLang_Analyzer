--  Precision regression for Global_Contract_Mismatch (FP-196, Ironclad's
--  Arch.Clocks.Initialize_Sources and Normalize_TSC_Hz): an Output global
--  that a called subprogram with no Global aspect gives a value on every
--  path, before the caller reads it. No read takes the value it had on
--  entry. Must not fire.
procedure Precision_Global_Contract_Mismatch_Callee_Write_Clean
  with SPARK_Mode
is
   package Clock with Abstract_State => State, Initializes => State is
      procedure Init (Ready : out Boolean) with Global => (Output => State);
   end Clock;

   package body Clock with Refined_State => (State => (Resolution, Seen)) is
      Resolution : Natural := 0;
      Seen       : Natural := 0;

      procedure Normalize (Scale : Natural := 10) is
      begin
         Resolution := 100;
         if Resolution > Scale then
            Resolution := Resolution / Scale;
         end if;
      end Normalize;

      procedure Init (Ready : out Boolean)
        with Refined_Global => (Output => (Resolution, Seen))
      is
      begin
         Normalize;
         Seen := Resolution;
         Ready := Seen > 0;
      end Init;
   end Clock;

   Ready : Boolean;
begin
   Clock.Init (Ready);
end Precision_Global_Contract_Mismatch_Callee_Write_Clean;
