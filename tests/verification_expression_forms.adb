package body Verification_Expression_Forms with SPARK_Mode => On is

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

   --  Whichever way the condition goes: 7 is more than 5.
   procedure If_Either (Flag : Boolean; Chosen : Integer) is
   begin
      Need_If (Flag, Chosen);
   end If_Either;

   --  The body of the function is its conditional expression.
   procedure If_Function (Risen : Integer) is
   begin
      pragma Assert (Signed (True, Risen));
   end If_Function;

   procedure If_Negated (Sunk : Integer) is
   begin
      pragma Assert (not Signed (False, Sunk));
   end If_Negated;

   --  A conditional expression that is a number.
   procedure If_Value (Any : Integer) is
   begin
      pragma Assert (Sign (Any) in -1 .. 1);
   end If_Value;

   procedure If_Chain (Product : Integer) is
   begin
      pragma Assert (Sign (Product) * Product >= 0);
   end If_Chain;

   --  The alternative of a literal.
   procedure Case_Literal (Sized : Integer) is
   begin
      Need_Case (Small, Sized);
   end Case_Literal;

   --  Every alternative: 20 is more than 0 and more than 10.
   procedure Case_Every (Which : Kind; Wide : Integer) is
   begin
      Need_Case (Which, Wide);
   end Case_Every;

   --  No "others": the three literals are every value of the type.
   procedure Case_Function (Shape : Kind; Roomy : Integer) is
   begin
      pragma Assert (Fits (Shape, Roomy));
   end Case_Function;

   --  What selects is known where the function is called.
   procedure Case_Chosen (Eleven : Integer) is
   begin
      pragma Assert (Fits (Medium, Eleven));
   end Case_Chosen;

   --  A case expression that is a number.
   procedure Case_Value (Given : Kind) is
   begin
      pragma Assert (Rank (Given) in 1 .. 2);
   end Case_Value;

   --  A Boolean component.
   procedure Component_Flag (Frame : Window) is
   begin
      Need_Open (Frame);
   end Component_Flag;

   --  Discriminants are read as components are.
   procedure Discriminants (Span : Window) is
   begin
      Need_Span (Span);
   end Discriminants;

   --  In SPARK code a discriminant is within its subtype.
   procedure Discriminant_Subtype (Based : Window) is
   begin
      pragma Assert (Based.Low >= 0);
   end Discriminant_Subtype;

   --  A formal is constrained where its actual is.
   procedure Passed_On (Loose : in out Window) is
   begin
      Refill (Loose);
   end Passed_On;

   --  Writing the object does not change whether it is constrained.
   procedure Passed_Twice (Twice : in out Window) is
   begin
      Refill (Twice);
      Refill (Twice);
   end Passed_Twice;

   --  A variable declared with the name of its type alone, every
   --  discriminant of which has a default, is not constrained.
   procedure Declared_Free is
      Fresh : Window;
   begin
      Refill (Fresh);
   end Declared_Free;

   procedure Held_Cell (Held : Cell) is
   begin
      Need_Cell (Held);
   end Held_Cell;

   --  Through a function and a component.
   procedure Held_In_Record (Packed : Crate) is
   begin
      Need_Cell (Packed.Inside);
   end Held_In_Record;

   --  Octet'Size is 8, and not zero.
   procedure Known_Divisor (Whole : Natural) is
   begin
      Aligned (Whole);
   end Known_Divisor;

end Verification_Expression_Forms;
