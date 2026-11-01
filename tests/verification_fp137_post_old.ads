--  FP-137: the checks of a postcondition were looked at a second time in the
--  state of the exit with no symbols, while X'Old was being read as it was on
--  entry. An object that had no symbol was then the object X'Old stands for,
--  and what was true of it on entry was taken for true at the exit: a 'Old in
--  a left operand of "and then" brought in the precondition. No claim of the
--  Bad_ subprograms follows: each body breaks what its postcondition's check
--  needs. Each Good_ subprogram is the same check on an object its body
--  leaves as it was, which the entry state does decide.
package Verification_FP137_Post_Old
  with SPARK_Mode
is
   type Cells is array (1 .. 3) of Integer;

   type Context is record
      C    : Cells := (others => 0);
      Mark : Integer := 0;
   end record;

   function Valid (Ctx : Context) return Boolean is (Ctx.C (1) > 0);

   function Get (Ctx : Context) return Integer is (Ctx.C (1))
     with Pre => Valid (Ctx);

   function Cells_Of (Ctx : Context) return Cells is (Ctx.C)
     with Pre => Valid (Ctx);

   Table : constant Cells := (1, 2, 3);

   procedure Bad_Division (Divisor : in out Integer)
     with Pre  => Divisor in 1 .. 100,
          Post => Divisor'Old > 0 and then 10 / Divisor >= 0;

   procedure Bad_Overflow (Sum : in out Integer)
     with Pre  => Sum in 0 .. 100,
          Post => Sum'Old >= 0 and then Sum + 1 > 0;

   procedure Bad_Index (Slot : in out Integer)
     with Pre  => Slot in 1 .. 3,
          Post => Slot'Old in 1 .. 3 and then Table (Slot) > 0;

   procedure Bad_Range (Count : in out Integer)
     with Pre  => Count in 0 .. 100,
          Post => Count'Old >= 0 and then Natural (Count) >= 0;

   procedure Bad_Element (Element_Ctx : in out Context; V : Integer)
     with Pre  => Valid (Element_Ctx),
          Post => Element_Ctx.Mark = Element_Ctx.Mark'Old
                    and then Get (Element_Ctx) = 1;

   procedure Bad_Whole (Whole_Ctx : in out Context; V : Cells)
     with Pre  => Valid (Whole_Ctx),
          Post => Whole_Ctx.Mark = Whole_Ctx.Mark'Old
                    and then Get (Whole_Ctx) = 1;

   procedure Bad_Update (Update_Ctx : in out Context; V : Cells)
     with Pre  => Valid (Update_Ctx),
          Post => Update_Ctx.Mark = Update_Ctx.Mark'Old
                    and then Get (Update_Ctx) = 1;

   procedure Good_Division (Kept_Divisor : in out Integer)
     with Pre  => Kept_Divisor in 1 .. 100,
          Post => Kept_Divisor'Old > 0 and then 10 / Kept_Divisor >= 0;

   procedure Good_Index (Kept_Slot : in out Integer)
     with Pre  => Kept_Slot in 1 .. 3,
          Post => Kept_Slot'Old in 1 .. 3 and then Table (Kept_Slot) > 0;

   procedure Good_Call (Kept_Ctx : in out Context)
     with Pre  => Valid (Kept_Ctx),
          Post => Kept_Ctx.Mark = Kept_Ctx.Mark'Old
                    and then Get (Kept_Ctx) > 0;

   --  An index into what a call returns is no call, and the postcondition
   --  it is in has its obligation like any other.
   procedure Good_Indexed (Indexed_Ctx : in out Context)
     with Pre  => Valid (Indexed_Ctx),
          Post => Cells_Of (Indexed_Ctx) (1) > 0;
end Verification_FP137_Post_Old;
