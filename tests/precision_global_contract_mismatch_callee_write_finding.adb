--  At the same shape, a callee that writes the Output global only on some
--  paths, or may return before writing it, leaves the value it had on
--  entry for the caller's read. Must fire, in both callers.
procedure Precision_Global_Contract_Mismatch_Callee_Write_Finding
  (Fast : Boolean)
  with SPARK_Mode
is
   package Clock with Abstract_State => State, Initializes => State is
      procedure Init (Ready : out Boolean) with Global => (Output => State);
      procedure Reset (Ready : out Boolean) with Global => (Output => State);
   end Clock;

   package body Clock with Refined_State => (State => (Resolution, Seen)) is
      Resolution : Natural := 0;
      Seen       : Natural := 0;
      Mode       : Boolean := False;

      procedure Normalize is
      begin
         if Mode then
            Resolution := 100;
         end if;
      end Normalize;

      procedure Calibrate is
      begin
         if Mode then
            return;
         end if;
         Resolution := 10;
      end Calibrate;

      procedure Init (Ready : out Boolean)
        with Refined_Global => (Output => (Resolution, Seen), Input => Mode)
      is
      begin
         Normalize;
         Seen := Resolution;
         Ready := Seen > 0;
      end Init;

      procedure Reset (Ready : out Boolean)
        with Refined_Global => (Output => (Resolution, Seen), Input => Mode)
      is
      begin
         Calibrate;
         Seen := Resolution;
         Ready := Seen > 0;
      end Reset;
   end Clock;

   Ready : Boolean;
begin
   if Fast then
      Clock.Init (Ready);
   else
      Clock.Reset (Ready);
   end if;
end Precision_Global_Contract_Mismatch_Callee_Write_Finding;
