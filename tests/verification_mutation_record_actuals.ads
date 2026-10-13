--  What is not known of a record given to a callee. Each call marked in
--  the body can fail its precondition for some value the subprogram can be
--  given: none of them is to be proved.
package Verification_Mutation_Record_Actuals with SPARK_Mode => On is

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
   procedure Swap_Wants (A, B : in out Item) with Pre => A.Count > 0;

   procedure Other_Object (Known, Other : Item) with Pre => Known.Count > 0;
   procedure Other_Component (Split : Pair) with Pre => Split.Left.Count > 0;
   procedure Other_Element (Line : Row) with Pre => Line (2).Count > 0;
   procedure Index_Unknown (Any : Row; Where : Integer)
     with Pre => Where in 1 .. 2 and then Any (2).Count > 0;
   procedure Written (Spent : in out Item) with Pre => Spent.Count > 0;
   procedure Half_Known (Bare : Item) with Pre => Bare.Count > 0;
   procedure Swapped (First, Second : in out Item)
     with Pre => First.Count > 0;

   procedure Fill (I : out Item) with Post => I.Count = 7;
   procedure Set (N : out Integer) with Post => N = 7;
   procedure Fill_At (I : out Item; K : in out Integer)
     with Post => I.Count = 7 and then K = 1;

   procedure Other_Filled (Apart : in out Pair);
   procedure Other_Set (Aside : in out Pair);
   procedure Filled_Then_Written (Redone : in out Pair; From : Item);
   procedure Index_Moved (Shelf : in out Row);

end Verification_Mutation_Record_Actuals;
