--  At the shape of the libgfxinit regression (FP-189): the body reads the
--  Output global before it writes it, the imported call before them
--  notwithstanding. Must fire.
procedure Precision_Global_Contract_Mismatch_Output_Import_Finding
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
         Show (Count);
         Count := 1;
      end Init;
   end Device;
begin
   Device.Init;
end Precision_Global_Contract_Mismatch_Output_Import_Finding;
