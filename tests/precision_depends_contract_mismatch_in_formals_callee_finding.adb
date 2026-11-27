--  At the shape of the in-formals regression (FP-182, FP-188): the Depends
--  aspect leaves out the formal that decides what the callee writes.
--  Must fire.
procedure Precision_Depends_Contract_Mismatch_In_Formals_Callee_Finding
  with SPARK_Mode
is
   package Panel with Abstract_State => State, Initializes => State is
      procedure Setup (Default_Delays : Boolean)
        with Global => (In_Out => State),
             Depends => (State => State, null => Default_Delays);
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
end Precision_Depends_Contract_Mismatch_In_Formals_Callee_Finding;
