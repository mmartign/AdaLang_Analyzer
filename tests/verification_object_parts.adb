package body Verification_Object_Parts with SPARK_Mode => On is

   --  One element is itself.
   procedure One_Element (Same : Items) is
   begin
      pragma Assert (Same (1).Count = Same (1).Count);
   end One_Element;

   --  What the precondition says of an element is known of that element.
   procedure Element_Kept (Kept : Items) is
   begin
      pragma Assert (Kept (1).Count = 5);
   end Element_Kept;

   --  The record formal of the function stands for the element.
   procedure Element_Passed (Tall : Items) is
   begin
      pragma Assert (Tall (1).Count = 5);
   end Element_Passed;

   --  The array formal stands for the array, element by element.
   procedure Array_Passed (Both : Items) is
   begin
      pragma Assert (Both (2).Count = 5);
   end Array_Passed;

   procedure Array_Passed_On (Whole : Items) is
   begin
      pragma Assert (Is_Five (Whole (1)));
   end Array_Passed_On;

   --  An index of an enumeration type, bound to a literal by the call.
   procedure Index_Literal (Set : Slots) is
   begin
      pragma Assert (Set (Second).Count = 5);
   end Index_Literal;

   --  An index that is a constant.
   procedure Index_Known (Line : Items) is
      Start : constant Integer := 1;
   begin
      pragma Assert (Line (Start).Count = 5);
   end Index_Known;

   --  An index whose value the state holds.
   procedure Index_Computed (Run : Items) is
      Position : Integer := 2;
   begin
      Position := Position - 1;
      pragma Assert (Run (Position).Count = 5);
   end Index_Computed;

   --  A component of a component.
   procedure Nested (Deep : Pair) is
   begin
      pragma Assert (Deep.Left.Count = 5);
   end Nested;

   procedure Nested_Passed (Inner : Pair) is
   begin
      pragma Assert (Is_Five (Inner.Left));
   end Nested_Passed;

   --  Through a private type to its full declaration.
   procedure Through_Private (Box : Holder) is
   begin
      pragma Assert (Box.Inner.Left.Count = 5);
   end Through_Private;

   --  Elements that are scalars: Grade (3) is more than a Natural.
   procedure Scalar_Element (Grade : Marks) is
   begin
      pragma Assert (Grade (3) > 0);
   end Scalar_Element;

   --  In SPARK code an element is within the subtype of the components.
   procedure Scalar_Subtype (Score : Marks) is
   begin
      pragma Assert (Score (2) >= 0);
   end Scalar_Subtype;

   procedure Boolean_Element (Bits : Flags) is
   begin
      pragma Assert (Bits (2));
   end Boolean_Element;

end Verification_Object_Parts;
