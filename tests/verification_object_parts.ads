--  Parts of an object that its name settles: a component of a record that
--  is itself a component, the element of an array at an index whose value
--  is known, and so on inwards. Each has a symbol of its own, and a record
--  or array formal of an expression function stands for the part that is
--  its actual. Every claim marked in the body holds; the ones that do not
--  are in Verification_Mutation_Object_Parts.
package Verification_Object_Parts with SPARK_Mode => On is

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
   function Both_Five (Row : Items) return Boolean is
     (Row (1).Count = 5 and then Row (2).Count = 5);
   function Slot_Five (Set : Slots; At_Place : Place) return Boolean is
     (Set (At_Place).Count = 5);
   function Held_Five (H : Holder) return Boolean;

   procedure One_Element (Same : Items);
   procedure Element_Kept (Kept : Items) with Pre => Kept (1).Count = 5;
   procedure Element_Passed (Tall : Items) with Pre => Is_Five (Tall (1));
   procedure Array_Passed (Both : Items) with Pre => Both_Five (Both);
   procedure Array_Passed_On (Whole : Items) with Pre => Both_Five (Whole);
   procedure Index_Literal (Set : Slots) with Pre => Slot_Five (Set, Second);
   procedure Index_Known (Line : Items) with Pre => Line (1).Count = 5;
   procedure Index_Computed (Run : Items) with Pre => Run (1).Count = 5;
   procedure Nested (Deep : Pair) with Pre => Deep.Left.Count = 5;
   procedure Nested_Passed (Inner : Pair) with Pre => Inner.Left.Count = 5;
   procedure Through_Private (Box : Holder) with Pre => Held_Five (Box);
   procedure Scalar_Element (Grade : Marks)
     with Pre => Grade (1) = 5 and then Grade (2) < Grade (3);
   procedure Scalar_Subtype (Score : Marks);
   procedure Boolean_Element (Bits : Flags) with Pre => Bits (2);

private

   type Holder is record
      Inner : Pair;
   end record;

   function Held_Five (H : Holder) return Boolean is (Is_Five (H.Inner.Left));

end Verification_Object_Parts;
