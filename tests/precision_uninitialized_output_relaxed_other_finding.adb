--  At the shape of the relaxed-initialization regression (FP-184): the
--  aspect names another parameter, and this one is left without a value
--  on a path. Must fire.
procedure Precision_Uninitialized_Output_Relaxed_Other_Finding
  with SPARK_Mode
is
   type Data is array (1 .. 8) of Integer;

   procedure Read_EDID (Raw : out Data; Copy : out Data; Ok : out Boolean)
   with Relaxed_Initialization => Raw
   is
   begin
      Ok := False;
      if Ok then
         Raw := (others => 0);
         Copy := Raw;
      end if;
   end Read_EDID;

   D, C : Data;
   Ok   : Boolean;
begin
   Read_EDID (D, C, Ok);
end Precision_Uninitialized_Output_Relaxed_Other_Finding;
