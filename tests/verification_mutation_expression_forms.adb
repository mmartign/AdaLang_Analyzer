package body Verification_Mutation_Expression_Forms with SPARK_Mode => On is

   procedure Need_If (Up : Boolean; Amount : Integer) is null;
   procedure Need_Case (K : Kind; Amount : Integer) is null;
   procedure Need_Open (W : Window) is null;
   procedure Need_Span (W : Window) is null;
   procedure Need_Cell (P : Cell) is null;
   procedure Aligned (Bits : Natural) is null;

   procedure Refill (W : in out Window) is
   begin
      W := (Low => 1, High => 2, Open => True, Level => 3);
   end Refill;

   --  4 is more than 3 and not more than 5: it fails when Flag is True.
   procedure If_Too_Low (Flag : Boolean; Low_Amount : Integer) is
   begin
      Need_If (Flag, Low_Amount);
   end If_Too_Low;

   --  It holds on one side of the condition only.
   procedure If_Wrong_Branch (Down : Boolean; Fallen : Integer) is
   begin
      pragma Assert (Signed (Down, Fallen));
   end If_Wrong_Branch;

   --  A conditional expression has the value of one of its dependent
   --  expressions, not of the first.
   procedure If_Value (Signless : Integer) is
   begin
      pragma Assert (Sign (Signless) = 1);
   end If_Value;

   --  Without an else part the expression is True where the condition is
   --  not, which says nothing of what follows "then".
   procedure If_Else_Missing (Unset : Boolean; Left_Alone : Integer) is
   begin
      pragma Assume (if Unset then Left_Alone > 5);
      pragma Assert (Left_Alone > 5);
   end If_Else_Missing;

   --  6 is more than 0 and not more than 10.
   procedure Case_Too_Low (Which : Kind; Narrow : Integer) is
   begin
      Need_Case (Which, Narrow);
   end Case_Too_Low;

   procedure Case_Function (Shape : Kind; Tight : Integer) is
   begin
      pragma Assert (Fits (Shape, Tight));
   end Case_Function;

   --  The alternative chosen is that of Medium, and 10 is not more than
   --  10.
   procedure Case_Chosen (Ten : Integer) is
   begin
      pragma Assert (Fits (Medium, Ten));
   end Case_Chosen;

   procedure Case_Value (Given : Kind) is
   begin
      pragma Assert (Rank (Given) = 1);
   end Case_Value;

   --  5 .. 15 is in two alternatives.
   procedure Case_Range (Digit : Integer) is
   begin
      pragma Assert (Tenth (Digit) = 1);
   end Case_Range;

   --  The level says nothing of the flag.
   procedure Component_Flag (Shut : Window) is
   begin
      Need_Open (Shut);
   end Component_Flag;

   --  Nor does one record of another.
   procedure Component_Other (Left, Right : Window) is
   begin
      Need_Open (Right);
   end Component_Other;

   --  Low may be High + 1.
   procedure Discriminants (Thin : Window) is
   begin
      Need_Span (Thin);
   end Discriminants;

   procedure Discriminant_Other (First, Second : Window) is
   begin
      Need_Span (Second);
   end Discriminant_Other;

   --  Nothing says the actual of this procedure is not constrained.
   procedure Not_Known (Unknown : in out Window) is
   begin
      Refill (Unknown);
   end Not_Known;

   --  A variable declared with a constraint is constrained.
   procedure Declared_Constrained is
      Fixed : Window (1, 2);
   begin
      Refill (Fixed);
   end Declared_Constrained;

   --  So is one declared with a constrained subtype.
   procedure Declared_Subtype is
      subtype Narrow_Window is Window (3, 4);
      Narrowed : Narrow_Window;
   begin
      Refill (Narrowed);
   end Declared_Subtype;

   --  What is known of one parameter is not known of another.
   procedure Other_Object (Free, Bound : in out Window) is
   begin
      Refill (Bound);
   end Other_Object;

   procedure Maybe_Null (Maybe : Cell) is
   begin
      Need_Cell (Maybe);
   end Maybe_Null;

   --  It is null where it is passed.
   procedure Made_Null (Dropped : in out Cell) is
   begin
      Dropped := null;
      Need_Cell (Dropped);
   end Made_Null;

   procedure Other_Cell (Full, Empty : Cell) is
   begin
      Need_Cell (Empty);
   end Other_Cell;

   --  4 is a multiple of 4 and not of 8.
   procedure Other_Divisor (Rough : Natural) is
   begin
      Aligned (Rough);
   end Other_Divisor;

end Verification_Mutation_Expression_Forms;
