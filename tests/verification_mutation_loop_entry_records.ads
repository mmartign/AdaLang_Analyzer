--  Seeded defects for what holds of arrays of records through a loop:
--  each claim named in the mutation manifest is false, and must never be
--  proved.
package Verification_Mutation_Loop_Entry_Records with SPARK_Mode is
   type Virtual_Field is (F_Initial, F_A, F_B, F_C, F_Final);
   subtype Field is Virtual_Field range F_A .. F_C;
   subtype Late is Virtual_Field range F_B .. F_C;
   type Cursor_State is (S_Valid, S_Invalid);
   type Field_Cursor is record
      State : Cursor_State := S_Invalid;
      Last  : Integer := 0;
   end record;
   type Field_Cursors is array (Virtual_Field) of Field_Cursor;
   type Context is record
      Cursors : Field_Cursors := (others => <>);
   end record;

   function Valid (C : Field_Cursor) return Boolean is (C.State = S_Valid);
   function Get (Ctx : Context; F : Field) return Integer with
     Pre => Valid (Ctx.Cursors (F));
   function Pos (A : Integer) return Integer with Pre => A > 0;

   --  E1 the prefix of 'Loop_Entry is evaluated on entry, where A is 0.
   procedure E1 (A : in out Integer; N : Natural);
   --  E2 the element is written in the loop: what it was on entry is not
   --  what it is.
   procedure E2 (Ctx : in out Context) with Pre => Valid (Ctx.Cursors (F_A));
   --  E3 a Late is at least F_B (GOOD), not more (BAD).
   procedure E3 (L : Late; Ok : out Boolean);
   --  E4 the entry value of the element is valid, the current one not.
   procedure E4 (Ctx : in out Context; N : Natural) with
     Pre => Valid (Ctx.Cursors (F_B));
end Verification_Mutation_Loop_Entry_Records;
