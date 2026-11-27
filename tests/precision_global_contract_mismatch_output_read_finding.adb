--  At the shape of the refined-state regression (FP-181): an Output
--  global that the body reads and never writes takes the value it had on
--  entry, which Output does not allow. Must fire.
procedure Precision_Global_Contract_Mismatch_Output_Read_Finding
  with SPARK_Mode
is
   package Outer with Abstract_State => State, Initializes => State is
      procedure Reset (V : out Integer) with Global => (Output => State);
   end Outer;

   package body Outer with Refined_State => (State => Count) is
      Count : Integer := 0;

      procedure Reset (V : out Integer) is
      begin
         V := Count;
      end Reset;
   end Outer;

   X : Integer;
begin
   Outer.Reset (X);
end Precision_Global_Contract_Mismatch_Output_Read_Finding;
