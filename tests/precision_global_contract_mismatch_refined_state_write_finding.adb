--  At the shape of the refined-state regression (FP-181): the Global
--  aspect allows only reading the state, and the body writes one of its
--  constituents. Must fire.
procedure Precision_Global_Contract_Mismatch_Refined_State_Write_Finding
  with SPARK_Mode
is
   package Outer with Abstract_State => State, Initializes => State is
      procedure Peek (V : out Integer) with Global => (Input => State);
   end Outer;

   package body Outer with Refined_State => (State => Count) is
      Count : Integer := 0;

      procedure Peek (V : out Integer) is
      begin
         Count := Count + 1;
         V := Count;
      end Peek;
   end Outer;

   X : Integer;
begin
   Outer.Peek (X);
end Precision_Global_Contract_Mismatch_Refined_State_Write_Finding;
