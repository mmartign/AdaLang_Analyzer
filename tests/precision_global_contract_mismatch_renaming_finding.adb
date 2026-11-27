--  At the shape of the refined-state regression (FP-181): a renaming
--  stands for the object it renames, and the Global aspect allows only
--  reading the state that object is a constituent of. Must fire.
procedure Precision_Global_Contract_Mismatch_Renaming_Finding
  with SPARK_Mode
is
   package Outer with Abstract_State => State, Initializes => State is
      procedure Bump with Global => (Input => State);
   end Outer;

   package body Outer with Refined_State => (State => Count) is
      Count : Integer := 0;
      Alias : Integer renames Count;

      procedure Bump is
      begin
         Alias := 1;
      end Bump;
   end Outer;
begin
   Outer.Bump;
end Precision_Global_Contract_Mismatch_Renaming_Finding;
