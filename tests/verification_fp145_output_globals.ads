--  FP-145 regression: the data dependencies of a subprogram are not proved
--  where its body may read the value on entry of a global its Global aspect
--  lists as Output only; GNATprove reports that global as not an input.
--  They still are where the body gives the whole global a value before it
--  reads it.
package Verification_FP145_Output_Globals with SPARK_Mode is

   X : Integer;
   R : Integer with Relaxed_Initialization;

   procedure Init with Global => (Output => X);

   --  Proved: the whole of X is written before it is read.
   procedure Write_Then_Read with Global => (Output => X);
   procedure Call_Then_Read with Global => (Output => X);
   procedure Both_Branches_Then_Read (C : Boolean)
     with Global => (Output => X);
   procedure Out_Actual_Then_Read with Global => (Output => X);
   --  FP-190: a for loop over a static range that is not empty goes round
   --  at least once.
   procedure Loop_Once_Then_Read with Global => (Output => X);
   --  FP-190: R, with relaxed initialization, need not be given a value
   --  on every path; the path that leaves the loop before the write does
   --  not read it (SPARK testsuite S530-019).
   procedure Exit_Then_Write_Relaxed (C : Boolean)
     with Global => (Output => R);

   --  Not proved: X may be read before it is written.
   procedure Read_Then_Write with Global => (Output => X);
   procedure Write_Under_Guard with Global => (Output => X);
   procedure Read_Only (Y : out Integer) with Global => (Output => X);
   --  Not proved: the loop may not go round, and X is read after it.
   procedure Loop_Maybe_Then_Read (N : Natural) with Global => (Output => X);
   --  Not proved: X, not relaxed, is not given a value on the path that
   --  leaves the loop before the write.
   procedure Exit_Then_Write (C : Boolean) with Global => (Output => X);

end Verification_FP145_Output_Globals;
