package body Verification_Mutation_Record_Actuals with SPARK_Mode => On is

   procedure Wants (I : Item) is null;

   procedure Wants_Ready (I : Item) is null;

   --  The callee is the caller, its parameters given the other way round:
   --  what is known of A is not known of B.
   procedure Swap_Wants (A, B : in out Item) is
   begin
      Swap_Wants (B, A);
   end Swap_Wants;

   --  Another object is given than the one that is known.
   procedure Other_Object (Known, Other : Item) is
   begin
      Wants (Other);
   end Other_Object;

   --  The other component of the record is given.
   procedure Other_Component (Split : Pair) is
   begin
      Wants (Split.Right);
   end Other_Component;

   --  The other element of the array is given.
   procedure Other_Element (Line : Row) is
   begin
      Wants (Line (1));
   end Other_Element;

   --  The element given is at an index that is not known.
   procedure Index_Unknown (Any : Row; Where : Integer) is
   begin
      Wants (Any (Where));
   end Index_Unknown;

   --  The component has been assigned since.
   procedure Written (Spent : in out Item) is
   begin
      Spent.Count := Spent.Count - 1;
      Wants (Spent);
   end Written;

   --  One of the two components the precondition reads is not known.
   procedure Half_Known (Bare : Item) is
   begin
      Wants_Ready (Bare);
   end Half_Known;

   --  The parameters of another subprogram, given the other way round.
   procedure Swapped (First, Second : in out Item) is
   begin
      Swap_Wants (Second, First);
   end Swapped;

   procedure Fill (I : out Item) is
   begin
      I := (Count => 7, Ready => True);
   end Fill;

   procedure Set (N : out Integer) is
   begin
      N := 7;
   end Set;

   procedure Fill_At (I : out Item; K : in out Integer) is
   begin
      I := (Count => 7, Ready => True);
      K := 1;
   end Fill_At;

   --  The callee wrote one component: the other is as it was.
   procedure Other_Filled (Apart : in out Pair) is
   begin
      Fill (Apart.Left);
      pragma Assert (Apart.Right.Count = 7);
   end Other_Filled;

   --  The same for a scalar component.
   procedure Other_Set (Aside : in out Pair) is
   begin
      Set (Aside.Left.Count);
      pragma Assert (Aside.Right.Count = 7);
   end Other_Set;

   --  The component has been assigned since the callee wrote it.
   procedure Filled_Then_Written (Redone : in out Pair; From : Item) is
   begin
      Fill (Redone.Left);
      Redone.Left := From;
      pragma Assert (Redone.Left.Count = 7);
   end Filled_Then_Written;

   --  The element given was the one the index picked when the call was
   --  made; the index has another value when it returns.
   procedure Index_Moved (Shelf : in out Row) is
      Position : Integer := 2;
   begin
      Fill_At (Shelf (Position), Position);
      pragma Assert (Shelf (Position).Count = 7);
   end Index_Moved;

end Verification_Mutation_Record_Actuals;
