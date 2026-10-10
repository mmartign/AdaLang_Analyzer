--  What is not known of the parts of an object. Each claim marked in the
--  body is false for some value the subprogram can be given, or was true
--  of a value that a statement has since replaced: none of them is to be
--  proved.
package Verification_Mutation_Object_Parts with SPARK_Mode => On is

   type Place is (First, Second);

   type Item is record
      Count : Integer;
      Ready : Boolean;
   end record;

   type Items is array (1 .. 2) of Item;
   type Slots is array (Place) of Item;
   type Marks is array (1 .. 3) of Natural;
   type Flags is array (1 .. 3) of Boolean;

   type Pair is record
      Left, Right : Item;
   end record;

   type Holder is private;

   function Is_Five (I : Item) return Boolean is (I.Count = 5);
   function Slot_Five (Set : Slots; At_Place : Place) return Boolean is
     (Set (At_Place).Count = 5);
   function Held_Five (H : Holder) return Boolean;

   procedure Change (Row : in out Items);

   procedure Other_Element (Apart : Items) with Pre => Apart (1).Count = 5;
   procedure Component_Written (Edited : in out Items)
     with Pre => Edited (1).Count = 5;
   procedure Element_Written (Replaced : in out Items)
     with Pre => Replaced (1).Count = 5;
   procedure Slice_Written (Shifted : in out Items; From : Items)
     with Pre => Shifted (1).Count = 5;
   procedure Object_Written (Renewed : in out Items; From : Items)
     with Pre => Renewed (1).Count = 5;
   procedure Passed_To_Call (Handed : in out Items)
     with Pre => Handed (1).Count = 5;
   procedure Other_Passed (Short : Items) with Pre => Is_Five (Short (1));
   procedure Other_Literal (Set : Slots) with Pre => Slot_Five (Set, Second);
   procedure Other_Side (Split : Pair) with Pre => Split.Left.Count = 5;
   procedure Other_Private (Box : Holder) with Pre => Held_Five (Box);
   procedure Index_Moved (Walk : Items) with Pre => Walk (1).Count = 5;
   procedure Index_Unknown (Any : Items; Where : Integer)
     with Pre => Where in 1 .. 2 and then Any (1).Count = 5;
   procedure Other_Scalar (Grade : Marks) with Pre => Grade (1) = 5;
   procedure Scalar_Written (Regraded : in out Marks)
     with Pre => Regraded (1) = 5;
   procedure Scalar_Above (Score : Marks);
   procedure Other_Boolean (Bits : Flags) with Pre => Bits (2);

private

   type Holder is record
      Inner : Pair;
   end record;

   function Held_Five (H : Holder) return Boolean is (Is_Five (H.Inner.Left));

end Verification_Mutation_Object_Parts;
