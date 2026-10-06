--  What a callee's postcondition says holds after the call, of the
--  caller's own objects: of the object the call was given to write, and of
--  the scalars it was given that it cannot have changed.
package Verification_Call_Postcondition with SPARK_Mode is

   type Cells is array (Positive range 1 .. 8) of Integer;
   type Context is record
      Used : Natural := 0;
      Data : Cells := (others => 0);
   end record;

   function Ready (Ctx : Context) return Boolean;
   function Room (Ctx : Context; Need : Natural) return Boolean;

   procedure Reset (Ctx : in out Context) with Post => Ready (Ctx);
   procedure Step (Ctx : in out Context)
     with Pre => Ready (Ctx), Post => Ready (Ctx);
   procedure Reserve (Ctx : in out Context; Need : Natural)
     with Pre => Ready (Ctx), Post => Ready (Ctx) and Room (Ctx, Need);
   procedure Fill (Ctx : in out Context; Need : Natural)
     with Pre => Ready (Ctx) and then Room (Ctx, Need);
   procedure Load (Ctx : out Context)
     with Import, Convention => C, Post => Ready (Ctx);

   --  Each call but the first is asked what the one before it gives.
   procedure In_Sequence;
   procedure With_Scalar (Need : Natural);
   procedure After_Unknown;
   procedure In_Loop;

end Verification_Call_Postcondition;
