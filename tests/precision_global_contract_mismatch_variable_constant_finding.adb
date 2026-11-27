--  At the shape of the refined-state regression (FP-181): a constant whose
--  value comes from a variable is a global like any object, and the
--  Global aspect leaves it out. Must fire.
procedure Precision_Global_Contract_Mismatch_Variable_Constant_Finding
  with SPARK_Mode
is
   Seed : Integer := 3;

   package Outer is
      procedure Get (V : out Integer) with Global => null;
   end Outer;

   package body Outer is
      Start : constant Integer := Seed;

      procedure Get (V : out Integer) is
      begin
         V := Start;
      end Get;
   end Outer;

   X : Integer;
begin
   Seed := 4;
   Outer.Get (X);
end Precision_Global_Contract_Mismatch_Variable_Constant_Finding;
