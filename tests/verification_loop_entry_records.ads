--  A loop that resets the elements of an array of records from a field on
--  (the shape of RecordFlux's Reset_Dependent_Fields): what the
--  precondition says of the elements on entry is said of the contents of
--  Ctx.Cursors'Loop_Entry, which the loop head keeps; the prefix of a
--  'Loop_Entry is decided where the loop is entered; a Field parameter is
--  within the positions of its subtype. Every check below is proved but
--  the postcondition, whose 'Old after the loop is not translated.
package Verification_Loop_Entry_Records with SPARK_Mode is
   type Virtual_Field is (F_Initial, F_A, F_B, F_C, F_Final);
   subtype Field is Virtual_Field range F_A .. F_C;
   subtype Late is Virtual_Field range F_B .. F_C;
   type Cursor_State is (S_Valid, S_Well_Formed, S_Invalid, S_Incomplete);
   type Field_Cursor is record
      State : Cursor_State := S_Invalid;
      First : Integer := 0;
      Last  : Integer := 0;
   end record;
   type Field_Cursors is array (Virtual_Field) of Field_Cursor;
   type Context is record
      First   : Integer := 1;
      Cursors : Field_Cursors := (others => <>);
   end record;

   function Valid (C : Field_Cursor) return Boolean is (C.State = S_Valid);
   function Valid_Next_Internal (Cursors : Field_Cursors; Fld : Field)
     return Boolean is
     (case Fld is
        when F_A => True,
        when F_B => Valid (Cursors (F_A)),
        when F_C => Valid (Cursors (F_B)));
   function Valid_Next (Ctx : Context; Fld : Field) return Boolean is
     (Valid_Next_Internal (Ctx.Cursors, Fld));
   function Field_First (Ctx : Context; Fld : Field) return Integer with
     Pre => Valid_Next (Ctx, Fld);
   function Invalid (Ctx : Context; Fld : Field) return Boolean is
     (Ctx.Cursors (Fld).State in S_Invalid | S_Incomplete);

   procedure Reset_Dependent_Fields (Ctx : in out Context; Fld : Field) with
     Pre  => Valid_Next (Ctx, Fld),
     Post => Valid_Next (Ctx, Fld)
             and Field_First (Ctx, Fld) = Field_First (Ctx, Fld)'Old
             and (for all F in Field =>
                    (if F < Fld then Ctx.Cursors (F) = Ctx.Cursors'Old (F)
                     else Invalid (Ctx, F)));

   --  A parameter of an enumeration subtype is within its positions.
   procedure Late_Field (L : Late; Ok : out Boolean);
end Verification_Loop_Entry_Records;
