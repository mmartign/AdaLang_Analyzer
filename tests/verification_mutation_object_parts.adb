package body Verification_Mutation_Object_Parts with SPARK_Mode => On is

   procedure Change (Row : in out Items) is
   begin
      Row (1).Count := 0;
   end Change;

   --  Nothing is known of the second element.
   procedure Other_Element (Apart : Items) is
   begin
      pragma Assert (Apart (2).Count = 5);
   end Other_Element;

   --  The component has been assigned.
   procedure Component_Written (Edited : in out Items) is
   begin
      Edited (1).Count := 6;
      pragma Assert (Edited (1).Count = 5);
   end Component_Written;

   --  The element has been assigned.
   procedure Element_Written (Replaced : in out Items) is
   begin
      Replaced (1) := Replaced (2);
      pragma Assert (Replaced (1).Count = 5);
   end Element_Written;

   --  A slice that holds the element has been assigned.
   procedure Slice_Written (Shifted : in out Items; From : Items) is
   begin
      Shifted (1 .. 2) := From;
      pragma Assert (Shifted (1).Count = 5);
   end Slice_Written;

   --  The whole array has been assigned.
   procedure Object_Written (Renewed : in out Items; From : Items) is
   begin
      Renewed := From;
      pragma Assert (Renewed (1).Count = 5);
   end Object_Written;

   --  A call has been given the array to write.
   procedure Passed_To_Call (Handed : in out Items) is
   begin
      Change (Handed);
      pragma Assert (Handed (1).Count = 5);
   end Passed_To_Call;

   --  The function was given the first element, not the second.
   procedure Other_Passed (Short : Items) is
   begin
      pragma Assert (Short (2).Count = 5);
   end Other_Passed;

   --  The call bound the index to Second, not to First.
   procedure Other_Literal (Set : Slots) is
   begin
      pragma Assert (Set (First).Count = 5);
   end Other_Literal;

   procedure Other_Side (Split : Pair) is
   begin
      pragma Assert (Split.Right.Count = 5);
   end Other_Side;

   procedure Other_Private (Box : Holder) is
   begin
      pragma Assert (Box.Inner.Right.Count = 5);
   end Other_Private;

   --  The index is 2 where the element is read.
   procedure Index_Moved (Walk : Items) is
      Position : Integer := 1;
   begin
      Position := Position + 1;
      pragma Assert (Walk (Position).Count = 5);
   end Index_Moved;

   --  The index may be 2.
   procedure Index_Unknown (Any : Items; Where : Integer) is
   begin
      pragma Assert (Any (Where).Count = 5);
   end Index_Unknown;

   procedure Other_Scalar (Grade : Marks) is
   begin
      pragma Assert (Grade (2) = 5);
   end Other_Scalar;

   --  Another element has been assigned: which is not worked out.
   procedure Scalar_Written (Regraded : in out Marks) is
   begin
      Regraded (1) := 7;
      pragma Assert (Regraded (1) = 5);
   end Scalar_Written;

   --  An element is a Natural, and may be zero.
   procedure Scalar_Above (Score : Marks) is
   begin
      pragma Assert (Score (2) > 0);
   end Scalar_Above;

   procedure Other_Boolean (Bits : Flags) is
   begin
      pragma Assert (Bits (1));
   end Other_Boolean;

end Verification_Mutation_Object_Parts;
