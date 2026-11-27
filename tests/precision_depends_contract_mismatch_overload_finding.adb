--  At the shape of the overload regression (FP-182): the Depends aspect
--  leaves out the formal passed on to the other Setup, which decides what
--  it writes. Must fire.
procedure Precision_Depends_Contract_Mismatch_Overload_Finding
  with SPARK_Mode
is
   package Panel with Abstract_State => State, Initializes => State is
      type Panels is (P1, P2);
      procedure Setup (Default_Delays : Boolean := False)
        with Global => (In_Out => State),
             Depends => (State => State, null => Default_Delays);
   end Panel;

   package body Panel with Refined_State => (State => Delays) is
      type Delay_Array is array (Panels) of Natural;
      Delays  : Delay_Array := (others => 0);
      Enabled : constant array (Panels) of Boolean := (P1 => True, P2 => False);

      procedure Setup (Which : Panels; Default_Delays : Boolean) is
         Override : Boolean := False;
      begin
         if Default_Delays then
            Override := True;
         elsif Delays (Which) < Natural'Last then
            Delays (Which) := Delays (Which) + 1;
         end if;
         if Override then
            Delays (Which) := 0;
         end if;
      end Setup;

      procedure Setup (Default_Delays : Boolean := False) is
      begin
         for Which in Panels loop
            if Enabled (Which) then
               Setup (Which, Default_Delays);
            end if;
         end loop;
      end Setup;
   end Panel;
begin
   Panel.Setup;
end Precision_Depends_Contract_Mismatch_Overload_Finding;
