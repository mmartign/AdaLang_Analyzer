--  Precision regression for Global_Contract_Mismatch (FP-189, libgfxinit's
--  HW.GFX.GMA.Initialize with libhwbase's Linux configuration): before the
--  write of an Output global, a call to an imported subprogram with no
--  Global aspect, which GNATprove takes to touch nothing (its "assumed
--  Global null"); the read after the write takes the value the body gave.
--  Must not fire.
procedure Precision_Global_Contract_Mismatch_Output_Import_Clean
  with SPARK_Mode
is
   package Device with Abstract_State => State, Initializes => State is
      procedure Init with Global => (Output => State);
   end Device;

   package body Device with Refined_State => (State => Count) is
      Count : Integer := 0;

      procedure Map with Import, Convention => C, External_Name => "map";

      procedure Show (X : Integer) with Global => null is
      begin
         pragma Unreferenced (X);
      end Show;

      procedure Init
        with Refined_Global => (Output => Count)
      is
      begin
         Map;
         Count := 1;
         Show (Count);
      end Init;
   end Device;
begin
   Device.Init;
end Precision_Global_Contract_Mismatch_Output_Import_Clean;
