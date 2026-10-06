--  Calls to functions of their arguments where what is known does not
--  carry over: the object has another value by then, the function is
--  another one, or its result does not depend on its arguments alone.
--  None of the calls named in the mutation manifest is to be proved.
package Verification_Mutation_Function_Terms with SPARK_Mode is

   type Cells is array (Positive range 1 .. 8) of Integer;
   type Cells_Access is access Cells;
   type Context is record
      Used : Natural := 0;
      Data : Cells := (others => 0);
      Heap : Cells_Access;
   end record;

   Shared : Cells_Access;
   Limit  : Natural := 4;

   function Ready (Ctx : Context) return Boolean;
   function Sum_Ok (Ctx : Context) return Boolean;
   function Below (Ctx : Context; Bound : Natural := 4) return Boolean;
   function Under_Limit (Ctx : Context) return Boolean;

   procedure Step (Ctx : in out Context) with Pre => Ready (Ctx);
   procedure Sum (Ctx : in out Context) with Pre => Sum_Ok (Ctx);
   procedure Low (Ctx : in out Context) with Pre => Below (Ctx, 2);
   procedure Capped (Ctx : in out Context) with Pre => Under_Limit (Ctx);

   --  The object has another value.
   procedure Element_Written (Written : in out Context)
     with Pre => Ready (Written);
   procedure Slice_Written (Sliced : in out Context)
     with Pre => Ready (Sliced);
   procedure Component_Written (Changed : in out Context)
     with Pre => Ready (Changed);
   procedure Renaming_Written (Renamed : in out Context)
     with Pre => Ready (Renamed);
   procedure Other_Formal_Written (First, Second : in out Context)
     with Pre => Ready (First);
   procedure Heap_Written (Pointing : in out Context)
     with Pre => Sum_Ok (Pointing);
   procedure Written_In_Loop (Looped : in out Context)
     with Pre => Ready (Looped);
   procedure Declared_In_Loop;
   procedure Called_Before (Again : in out Context)
     with Pre => Ready (Again);

   --  Another function: the default is another argument.
   procedure Default_Differs (Defaulted : in out Context)
     with Pre => Below (Defaulted);

   --  Not a function of its arguments: it reads Limit.
   procedure Variable_Read (Capped_Ctx : in out Context)
     with Pre => Under_Limit (Capped_Ctx);

   --  A function that is not in SPARK may write through an access value
   --  it is given, wherever in the expression it is called.
   package Loose with SPARK_Mode => Off is
      function Poke (Target : Cells_Access) return Boolean;
   end Loose;

   procedure Poked_Before (Poked : in out Context; Flag : out Boolean)
     with Pre => Sum_Ok (Poked);
   procedure Poked_In_Condition (Tested : in out Context)
     with Pre => Sum_Ok (Tested);
   procedure Poked_After_Guard (Guarded : in out Context);

   --  One generic function is another function in each instance.
   generic
      Bound : Natural;
   package Bounded with SPARK_Mode is
      function Fits (Ctx : Context) return Boolean;
      procedure Use_It (Ctx : in out Context) with Pre => Fits (Ctx);
   end Bounded;

   package Small is new Bounded (1);
   package Large is new Bounded (100);

   procedure Other_Instance (Mixed : in out Context)
     with Pre => Large.Fits (Mixed);

end Verification_Mutation_Function_Terms;
