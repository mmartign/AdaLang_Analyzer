package body Verification_Record_Actuals with SPARK_Mode => On is

   procedure Wants (I : Item) is null;

   procedure Wants_Ready (I : Item) is null;

   --  The object the precondition speaks of is the one given.
   procedure Whole_Object (Given : Item) is
   begin
      Wants (Given);
   end Whole_Object;

   --  A component of a record is an object of its own.
   procedure Component (Outer : Pair) is
   begin
      Wants (Outer.Left);
   end Component;

   --  Each component the precondition reads is found in the part given.
   procedure Deep_Component (Nest : Pair) is
   begin
      Wants_Ready (Nest.Right);
   end Deep_Component;

   --  So is an element of an array at an index that is known.
   procedure Element (Line : Row) is
   begin
      Wants (Line (2));
   end Element;

   --  What a test has shown of the object is known where it is given.
   procedure After_Test (Tried : Item) is
   begin
      if Tried.Ready and then Tried.Count > 3 then
         Wants_Ready (Tried);
      end if;
   end After_Test;

   procedure Fill (I : out Item) is
   begin
      I := (Count => 7, Ready => True);
   end Fill;

   procedure Set (N : out Integer) is
   begin
      N := 7;
   end Set;

   --  The callee wrote the component it was given.
   procedure Component_Filled (Kept : in out Pair) is
   begin
      Fill (Kept.Left);
      pragma Assert (Kept.Left.Count = 7);
   end Component_Filled;

   --  A scalar component is written the same way.
   procedure Scalar_Set (Held : in out Pair) is
   begin
      Set (Held.Right.Count);
      pragma Assert (Held.Right.Count = 7);
   end Scalar_Set;

   --  What one callee left in the component the next one finds there.
   procedure Filled_Then_Given (Sent : in out Pair) is
   begin
      Fill (Sent.Right);
      Wants_Ready (Sent.Right);
   end Filled_Then_Given;

end Verification_Record_Actuals;
