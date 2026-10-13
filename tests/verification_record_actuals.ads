--  A record given to a callee is, where the callee's precondition is
--  checked, the object the caller gives: a component the precondition
--  reads is the component of that object, whether the object is a whole
--  one, a component of another or an element of an array. What the
--  callee's postcondition says of a parameter it writes is likewise said
--  of the component of a record that was given for it. Every call marked
--  in the body satisfies its precondition, and every claim holds; the ones
--  that do not are in Verification_Mutation_Record_Actuals.
package Verification_Record_Actuals with SPARK_Mode => On is

   type Item is record
      Count : Integer;
      Ready : Boolean;
   end record;

   type Pair is record
      Left, Right : Item;
   end record;

   type Row is array (1 .. 2) of Item;

   procedure Wants (I : Item) with Pre => I.Count > 0;
   procedure Wants_Ready (I : Item) with Pre => I.Ready and then I.Count > 0;

   procedure Whole_Object (Given : Item) with Pre => Given.Count > 0;
   procedure Component (Outer : Pair) with Pre => Outer.Left.Count > 0;
   procedure Deep_Component (Nest : Pair)
     with Pre => Nest.Right.Ready and then Nest.Right.Count > 3;
   procedure Element (Line : Row) with Pre => Line (2).Count > 0;
   procedure After_Test (Tried : Item);

   procedure Fill (I : out Item) with Post => I.Count = 7 and then I.Ready;
   procedure Set (N : out Integer) with Post => N = 7;

   procedure Component_Filled (Kept : in out Pair);
   procedure Scalar_Set (Held : in out Pair);
   procedure Filled_Then_Given (Sent : in out Pair);

end Verification_Record_Actuals;
