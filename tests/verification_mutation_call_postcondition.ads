--  Postconditions that say nothing of what is asked after the call: the
--  fact is about another object or another value, the object has changed
--  since, or the formal does not stand for what the caller sees. None of
--  the calls named in the mutation manifest is to be proved.
package Verification_Mutation_Call_Postcondition with SPARK_Mode is

   type Cells is array (Positive range 1 .. 8) of Integer;
   type Cells_Access is access Cells;
   type Context is record
      Used : Natural := 0;
      Data : Cells := (others => 0);
      Heap : Cells_Access;
   end record;

   Shared : Context;
   Demand : Natural := 2;

   function Ready (Ctx : Context) return Boolean;
   function Room (Ctx : Context; Need : Natural) return Boolean;

   package Loose with SPARK_Mode => Off is
      function Poke (Target : Cells_Access) return Boolean;
   end Loose;

   procedure Reset (Ctx : in out Context) with Post => Ready (Ctx);
   procedure Step (Ctx : in out Context) with Pre => Ready (Ctx);
   procedure Reserve (Ctx : in out Context; Need : Natural)
     with Post => Room (Ctx, Need);
   procedure Reserve_Default (Ctx : in out Context; Need : Natural := 2)
     with Post => Room (Ctx, Need);
   procedure Fill (Ctx : in out Context; Need : Natural)
     with Pre => Room (Ctx, Need);
   procedure Reset_And_Raise (Ctx : in out Context; Need : in out Natural)
     with Post => Room (Ctx, Need);
   procedure Reset_Shared (Ctx : in out Context) with Post => Ready (Ctx);
   procedure Copy (From : Context; To : in out Context)
     with Post => Ready (From);
   procedure Poked (Ctx : in out Context)
     with Post => Ready (Ctx) and then Loose.Poke (Ctx.Heap);

   procedure Other_Object;
   procedure Written_After;
   procedure Other_Value;
   procedure Global_Argument;
   procedure Argument_Written;
   procedure Default_Argument;
   procedure Only_Once;
   procedure Global_Actual;
   procedure Same_Object;
   procedure Untrusted_Postcondition;
   procedure From_Inside;

end Verification_Mutation_Call_Postcondition;
