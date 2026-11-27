--  Precision regression for Global_Contract_Mismatch (FP-189, tokeneer's
--  AdminToken.Init): inside the package body, a call is held to the
--  callee's Refined_Global, not to its Global. Clear is In_Out of the
--  state for its callers outside, Output of every constituent inside, so
--  Init, which lists the state as Output, does not read it. Must not fire.
procedure Precision_Global_Contract_Mismatch_Refined_Callee_Clean
  with SPARK_Mode
is
   package Token with Abstract_State => State, Initializes => State is
      procedure Clear with Global => (In_Out => State);
      procedure Init with Global => (Output => State);
   end Token;

   package body Token with Refined_State => (State => (Present, Tries)) is
      Present : Boolean := False;
      Tries   : Natural := 0;

      procedure Clear
        with Refined_Global => (Output => (Present, Tries))
      is
      begin
         Present := False;
         Tries := 0;
      end Clear;

      procedure Init
        with Refined_Global => (Output => (Present, Tries))
      is
      begin
         Clear;
      end Init;
   end Token;
begin
   Token.Init;
end Precision_Global_Contract_Mismatch_Refined_Callee_Clean;
