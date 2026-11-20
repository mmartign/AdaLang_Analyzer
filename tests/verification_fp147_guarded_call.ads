--  FP-147 regression: a call whose actuals make the precondition false is a
--  definite error only where the call is reached, as an assertion that is
--  false is (FP-065). Found on Alire (alr-commands-self_update.adb):
--  "if On_Windows and then ... then Windows_Copy_And_Relaunch (...)", the
--  precondition of the procedure being On_Windows, a function that is the
--  constant False on the host analyzed. The subprogram declares an object
--  of a tagged type, which may run code unseen, so the symbolic state is
--  dropped at every node and the guard with it; the solver then refuted
--  the precondition with nothing assumed.
package Verification_FP147_Guarded_Call is

   type Systems is (Linux, MacOS, Windows);

   function Operating_System return Systems;

   function On_Windows return Boolean is (Operating_System in Windows);

   procedure Windows_Only (N : Natural)
   with Pre => On_Windows;

   --  The call is under the guard: unproved, not a definite error.
   procedure Guarded (Count : Natural);

   --  The call is reached whenever the procedure runs: a definite error.
   procedure Unguarded (Total : Natural);

end Verification_FP147_Guarded_Call;
