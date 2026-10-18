--  What is known of the parts of a record object stands where another of
--  its parts is written, where a call writes another part or no part of it
--  at all, and where a condition or an assertion gives the translation
--  nothing to take; a function called without an argument list is its
--  body where it is called. Each assertion of Written_Part, Whole_Written,
--  Part_Given, Stale_Invariant, Changing_Function and Effectful_Guard
--  fails at run time. The others hold. Outside SPARK code a write to a
--  part of a parameter may write another parameter, or an object the
--  subprogram names: the division of Two_Names fails when both actuals are
--  one object, and that of Global_Name when its actual is G_Shared.
package Verification_Part_Frames is

   type Ptr is access Integer;

   type Slots is record
      S1, S2 : Ptr;
   end record;

   type Inner is record
      Slots : Verification_Part_Frames.Slots;
      Next  : Integer;
      Count : Natural;
   end record;

   type Context is record
      P : Inner;
   end record;

   function Free (S : Slots) return Boolean is
     (S.S1 = null and S.S2 = null) with SPARK_Mode;

   function Ready (Ctx : Context) return Boolean is
     (Free (Ctx.P.Slots) and Ctx.P.Count = 0) with SPARK_Mode;

   procedure Bump (X : in out Natural) with
     SPARK_Mode, Global => null, Pre => X < Natural'Last;

   procedure Reset (Ctx : in out Context) with SPARK_Mode, Global => null;

   procedure Needs_Free (S : Slots) with
     SPARK_Mode, Global => null, Pre => Free (S);

   procedure Invariant_Kept (Ctx : in out Context; Key : String) with
     SPARK_Mode, Pre => Ready (Ctx);
   procedure Written_Part (Ctx : in out Context) with
     SPARK_Mode, Pre => Ready (Ctx);
   procedure Whole_Written (Ctx : in out Context) with
     SPARK_Mode, Pre => Ready (Ctx);
   procedure Part_Given (Ctx : in out Context) with
     SPARK_Mode, Pre => Ready (Ctx);
   procedure Stale_Invariant (Ctx : in out Context) with
     SPARK_Mode, Pre => Ready (Ctx);
   procedure Changing_Function with SPARK_Mode;

   Calls : Integer := 0;
   function Noisy return Boolean;
   procedure Effectful_Guard;

   type Shared_Rec is limited record
      X, Y : Integer;
   end record;

   G_Shared : Shared_Rec := (X => 1, Y => 1);

   procedure Two_Names (R1, R2 : in out Shared_Rec; Sink : out Integer);
   procedure Global_Name (R : in out Shared_Rec; Sink : out Integer);

end Verification_Part_Frames;
