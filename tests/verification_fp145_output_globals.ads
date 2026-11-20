--  FP-145 regression: the data dependencies of a subprogram are not proved
--  where its body may read the value on entry of a global its Global aspect
--  lists as Output only; GNATprove reports that global as not an input.
--  They still are where the body gives the whole global a value before it
--  reads it.
package Verification_FP145_Output_Globals with SPARK_Mode is

   X : Integer;

   procedure Init with Global => (Output => X);

   --  Proved: the whole of X is written before it is read.
   procedure Write_Then_Read with Global => (Output => X);
   procedure Call_Then_Read with Global => (Output => X);
   procedure Both_Branches_Then_Read (C : Boolean)
     with Global => (Output => X);
   procedure Out_Actual_Then_Read with Global => (Output => X);

   --  Not proved: X may be read before it is written.
   procedure Read_Then_Write with Global => (Output => X);
   procedure Write_Under_Guard with Global => (Output => X);
   procedure Read_Only (Y : out Integer) with Global => (Output => X);

end Verification_FP145_Output_Globals;
