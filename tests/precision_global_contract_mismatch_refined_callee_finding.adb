--  At the shape of the AdminToken regression (FP-189): the callee's
--  Refined_Global reads a constituent (In_Out), so Init, which lists the
--  state as Output, reads it on entry. Must fire.
procedure Precision_Global_Contract_Mismatch_Refined_Callee_Finding
  with SPARK_Mode
is
   package Token with Abstract_State => State, Initializes => State is
      procedure Bump with Global => (In_Out => State);
      procedure Init with Global => (Output => State);
   end Token;

   package body Token with Refined_State => (State => (Present, Tries)) is
      Present : Boolean := False;
      Tries   : Natural := 0;

      procedure Bump
        with Refined_Global => (Output => Present, In_Out => Tries)
      is
      begin
         Present := True;
         if Tries < Natural'Last then
            Tries := Tries + 1;
         end if;
      end Bump;

      procedure Init
        with Refined_Global => (Output => (Present, Tries))
      is
      begin
         Bump;
      end Init;
   end Token;
begin
   Token.Init;
end Precision_Global_Contract_Mismatch_Refined_Callee_Finding;
