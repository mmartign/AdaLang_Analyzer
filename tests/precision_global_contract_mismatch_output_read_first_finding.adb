--  At the shape of the refined-state regression (FP-181): an Output
--  global that the body reads before it writes it takes the value it had
--  on entry, which Output does not allow, though the body writes it too
--  (Ada-Lisp's decrement_exit_block). Must fire.
procedure Precision_Global_Contract_Mismatch_Output_Read_First_Finding
  with SPARK_Mode
is
   package Outer with Abstract_State => State, Initializes => State is
      procedure Decrement with Global => (Output => State);
   end Outer;

   package body Outer with Refined_State => (State => Count) is
      Count : Natural := 0;

      procedure Decrement is
      begin
         if Count > 0 then
            Count := Count - 1;
         end if;
      end Decrement;
   end Outer;
begin
   Outer.Decrement;
end Precision_Global_Contract_Mismatch_Output_Read_First_Finding;
