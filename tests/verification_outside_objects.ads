--  What a subprogram takes from outside it, what a call leaves of the
--  globals it writes, and the parts of a record or an array that are given
--  a value one by one: every initialization here is proved. The defects
--  are in verification_mutation_outside_objects. GNATprove proves all of it
--  (tests/run_gnatprove_differential.sh).
package Verification_Outside_Objects
  with SPARK_Mode
is
   Shared : Integer;

   type Cells is array (1 .. 4) of Integer;
   subtype Few is Integer range 1 .. 2;
   type Few_Cells is array (Few) of Integer;
   type Pair is record
      P, Q : Integer;
   end record;
   type Whole is record
      A : Integer;
      B : Cells;
   end record;
   type Nest is record
      I : Pair;
      Z : Integer;
   end record;
   type Base is tagged record
      A : Integer;
   end record;
   type Extended is new Base with record
      B : Integer;
   end record;
   type Sized (N : Natural := 0) is record
      L : Integer := 0;
   end record;

   package Keeper with Abstract_State => Kept, Initializes => null is
      procedure Store with Global => (Output => Kept);
      procedure Fetch (R : out Integer) with Global => (Input => Kept);
   end Keeper;

   procedure Read_Shared (R : out Integer) with Global => (Input => Shared);
   procedure Set_Shared with Global => (Output => Shared);
   procedure Keep_Shared with Global => (In_Out => Shared);
   function Shared_Value return Integer with Global => (Input => Shared);

   --  An Output global a call gives a value to.
   procedure Set_Then_Read (R : out Integer)
     with Global => (Output => Shared);
   --  It still has one after a call that writes it again.
   procedure Set_Then_Keep (R : out Integer)
     with Global => (Output => Shared);
   --  A function called with no actuals reads it too.
   procedure Set_Then_Bare (R : out Integer)
     with Global => (Output => Shared);
   --  An Input global is the caller's to give a value to.
   procedure Pass_On (R : out Integer) with Global => (Input => Shared);
   --  With no Global aspect, what the body reads.
   procedure Generated (R : out Integer);
   --  A state abstraction, through the call that writes it.
   procedure Store_Kept with Global => (Output => Keeper.Kept);

   --  An object of the enclosing subprogram.
   procedure Nested_Input (R : out Integer) with Global => null;
   procedure Nested_Output (R : out Integer) with Global => null;

   --  An object of the enclosing subprogram, read by a nested subprogram
   --  that the call in an elaboration of it reaches.
   procedure Through_Formal (R : out Integer) with Global => null;

   procedure By_Components (By_Assignment : out Whole);
   procedure By_Calls (By_Actuals : out Whole);
   procedure Nested_Components (Deep : out Nest);
   procedure Extension (Extended_Value : out Extended);
   function Part_Read return Integer;

   procedure Range_Loop (Filled : out Cells);
   procedure Backward_Loop (Backward : out Cells);
   procedure Index_Loop (Indexed : out Few_Cells);
   procedure Component_Loop (Field : out Whole);
   function Local_Loop return Integer;

   --  No attribute of these reads the value.
   procedure Fresh (Unset : out Sized) with Pre => not Unset'Constrained;

   --  The aspect of a subprogram is for the parameters it names, and an
   --  object an index of the actual reads is not written.
   type Open_Cells is array (Positive range <>) of Integer;
   procedure Listed (X : out Open_Cells; N : out Integer)
     with Relaxed_Initialization => (X);
   function Unlisted_Read return Integer;
   function Index_Read return Integer;
end Verification_Outside_Objects;
