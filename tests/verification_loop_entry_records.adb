package body Verification_Loop_Entry_Records with SPARK_Mode is
   function Field_First (Ctx : Context; Fld : Field) return Integer is
     (case Fld is
        when F_A => Ctx.First,
        when F_B => Ctx.Cursors (F_A).Last + 1,
        when F_C => Ctx.Cursors (F_B).Last + 1);

   procedure Reset_Dependent_Fields (Ctx : in out Context; Fld : Field) is
   begin
      for Fld_Loop in reverse Fld .. Field'Last loop
         pragma Loop_Invariant (Field_First (Ctx, Fld) = Field_First (Ctx, Fld)'Loop_Entry);
         pragma Loop_Invariant ((for all F in Field => (if F <= Fld_Loop then Ctx.Cursors (F) = Ctx.Cursors'Loop_Entry (F) else Invalid (Ctx, F))));
         Ctx.Cursors (Fld_Loop) := (State => S_Invalid, others => <>);
      end loop;
   end Reset_Dependent_Fields;

   procedure Late_Field (L : Late; Ok : out Boolean) is
   begin
      pragma Assert (L >= F_B and then L <= F_C);
      Ok := True;
   end Late_Field;
end Verification_Loop_Entry_Records;
