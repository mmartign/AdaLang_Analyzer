--  A call to a function of its arguments is a term: what is known of it
--  for one value of its arguments is known wherever it is called with the
--  same value.
package Verification_Function_Terms with SPARK_Mode is

   type Cells is array (Positive range 1 .. 8) of Integer;
   type Context is private;

   Threshold : Natural := 0;

   function Ready (Ctx : Context) return Boolean;
   function Room (Ctx : Context; Need : Natural) return Boolean;
   function Left (Ctx : Context) return Natural with Pre => Ready (Ctx);

   --  Reads a variable: not a function of its arguments.
   function Armed (Ctx : Context) return Boolean;

   --  Not an expression function: a term, and nothing of what it computes.
   function Checked (Ctx : Context) return Boolean;

   procedure Step (Ctx : in out Context) with Pre => Ready (Ctx);
   procedure Fill (Ctx : in out Context; Need : Natural)
     with Pre => Ready (Ctx) and then Room (Ctx, Need);
   procedure Fire (Ctx : in out Context) with Pre => Armed (Ctx);
   procedure Trust (Ctx : in out Context) with Pre => Checked (Ctx);

   --  What the caller's precondition says is what the callee's asks.
   procedure Forward (Whole : in out Context) with Pre => Ready (Whole);
   procedure Forward_Both (Both : in out Context; Need : Natural)
     with Pre => Ready (Both) and then Room (Both, Need);
   procedure Forward_Named (Named : in out Context; Need : Natural)
     with Pre => Room (Need => Need, Ctx => Named) and then Ready (Named);

   procedure Forward_Term (Passed : in out Context)
     with Pre => Checked (Passed);

   --  The call to Left stands behind the operand that is its precondition.
   procedure Guarded (Kept : in out Context)
     with Pre => Ready (Kept) and then Left (Kept) > 0;

   --  Ready is an expression function, and what it reads is the component
   --  Used: writing an element of Data leaves it as it was.
   procedure After_Element (Written : in out Context)
     with Pre => Ready (Written);
   procedure On_One_Path (Joined : in out Context; Flag : Boolean)
     with Pre => Ready (Joined);

   --  The object is not the one the fact is about, or no longer has the
   --  value it was about.
   procedure Twice (Again : in out Context) with Pre => Ready (Again);
   procedure Other_Object (Known, Other : in out Context)
     with Pre => Ready (Known);
   procedure Other_Argument (Sized : in out Context; Need, More : Natural)
     with Pre => Ready (Sized) and then Room (Sized, Need);
   procedure After_Element_Term (Marked : in out Context)
     with Pre => Checked (Marked);
   procedure After_Component (Changed : in out Context)
     with Pre => Ready (Changed);
   procedure After_Assignment (Replaced : in out Context; From : Context)
     with Pre => Ready (Replaced);
   procedure In_Loop (Repeated : in out Context) with Pre => Ready (Repeated);
   procedure On_One_Path_Term (Merged : in out Context; Flag : Boolean)
     with Pre => Checked (Merged);
   procedure Unguarded (Loose : in out Context)
     with Pre => Left (Loose) > 0;

   --  The function reads Threshold, which the caller changes.
   procedure With_Global (Aimed : in out Context) with Pre => Armed (Aimed);

private

   type Context is record
      Used : Natural := 0;
      Data : Cells := (others => 0);
   end record;

   function Ready (Ctx : Context) return Boolean is (Ctx.Used < 8);
   function Room (Ctx : Context; Need : Natural) return Boolean is
     (Need <= 8 and then Ctx.Used <= 8 - Need);
   function Left (Ctx : Context) return Natural is (8 - Ctx.Used);
   function Armed (Ctx : Context) return Boolean is
     (Ctx.Used > Threshold);

end Verification_Function_Terms;
