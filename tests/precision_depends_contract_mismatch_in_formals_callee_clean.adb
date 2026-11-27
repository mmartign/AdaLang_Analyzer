--  Precision regression for Depends_Contract_Mismatch (FP-182, FP-188,
--  libgfxinit's Panel.Setup_PP_Sequencer and DP_Aux_Request's
--  Write_Data_Reg): a callee with no contract whose formals are all of
--  mode in writes a state as they say, so the state depends on what the
--  caller passes. Must not fire.
procedure Precision_Depends_Contract_Mismatch_In_Formals_Callee_Clean
  with SPARK_Mode
is
   package Panel with Abstract_State => State, Initializes => State is
      procedure Setup (Default_Delays : Boolean)
        with Global => (In_Out => State),
             Depends => (State => (State, Default_Delays));
   end Panel;

   package body Panel with Refined_State => (State => Delays) is
      Delays : Natural := 0;

      procedure Set (Use_Default : Boolean) with SPARK_Mode => Off is
      begin
         if Use_Default then
            Delays := 0;
         elsif Delays < Natural'Last then
            Delays := Delays + 1;
         end if;
      end Set;

      procedure Setup (Default_Delays : Boolean) is
      begin
         Set (Default_Delays);
      end Setup;
   end Panel;
begin
   Panel.Setup (True);
end Precision_Depends_Contract_Mismatch_In_Formals_Callee_Clean;
