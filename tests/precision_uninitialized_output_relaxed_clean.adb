--  Precision regression for Uninitialized_Output (FP-184, libgfxinit's
--  Read_EDID): an out parameter with relaxed initialization -- the aspect
--  on the subprogram naming it, or on its type -- may be left without a
--  value; its postcondition says when it has one, which is for proof.
procedure Precision_Uninitialized_Output_Relaxed_Clean with SPARK_Mode is
   type Data is array (1 .. 8) of Integer;
   type Loose is array (1 .. 8) of Integer with Relaxed_Initialization;

   procedure Read_EDID (Raw : out Data; Ok : out Boolean)
   with Relaxed_Initialization => Raw,
        Post => (if Ok then Raw'Initialized)
   is
   begin
      Ok := False;
      if Ok then
         Raw := (others => 0);
      end if;
   end Read_EDID;

   procedure Read_Loose (Raw : out Loose; Ok : out Boolean) is
   begin
      Ok := False;
      if Ok then
         Raw := (others => 0);
      end if;
   end Read_Loose;

   D  : Data;
   L  : Loose;
   Ok : Boolean;
begin
   Read_EDID (D, Ok);
   Read_Loose (L, Ok);
end Precision_Uninitialized_Output_Relaxed_Clean;
