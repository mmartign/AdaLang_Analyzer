--  What the expression forms of Verification_Expression_Forms do not
--  say. Each claim marked in the body is false for some value the
--  subprogram can be given, or rests on nothing the analysis may rely on:
--  none of them is to be proved.
package Verification_Mutation_Expression_Forms with SPARK_Mode => On is

   type Kind is (Small, Medium, Large);

   type Window (Low : Natural := 0; High : Natural := 10) is record
      Open  : Boolean := False;
      Level : Natural := 0;
   end record;

   type Cell is access constant Integer;

   function Fits (K : Kind; Size : Integer) return Boolean is
     (case K is
         when Small  => Size > 0,
         when Medium => Size > 10,
         when Large  => True);

   function Signed (Up : Boolean; Step : Integer) return Boolean is
     (if Up then Step > 0 else Step < 0);

   function Rank (K : Kind) return Integer is
     (case K is when Small => 1, when Medium | Large => 2);

   function Sign (Value : Integer) return Integer is
     (if Value > 0 then 1 elsif Value < 0 then -1 else 0);

   function Tenth (Value : Integer) return Integer is
     (case Value is when 1 .. 9 => 1, when 10 .. 99 => 2, when others => 3);

   procedure Need_If (Up : Boolean; Amount : Integer)
     with Pre => (if Up then Amount > 5);
   procedure Need_Case (K : Kind; Amount : Integer)
     with Pre => (case K is when Small => Amount > 0, when others => Amount > 10);
   procedure Need_Open (W : Window) with Pre => W.Open;
   procedure Need_Span (W : Window) with Pre => W.Low <= W.High;
   procedure Refill (W : in out Window) with Pre => not W'Constrained;
   procedure Need_Cell (P : Cell) with Pre => P /= null;
   procedure Aligned (Bits : Natural) with Pre => Bits mod 8 = 0;

   procedure If_Too_Low (Flag : Boolean; Low_Amount : Integer)
     with Pre => Low_Amount > 3;
   procedure If_Wrong_Branch (Down : Boolean; Fallen : Integer)
     with Pre => Fallen > 0;
   procedure If_Value (Signless : Integer);
   procedure If_Else_Missing (Unset : Boolean; Left_Alone : Integer);

   procedure Case_Too_Low (Which : Kind; Narrow : Integer)
     with Pre => Narrow > 5;
   procedure Case_Function (Shape : Kind; Tight : Integer)
     with Pre => Tight > 5;
   procedure Case_Chosen (Ten : Integer) with Pre => Ten = 10;
   procedure Case_Value (Given : Kind);
   procedure Case_Range (Digit : Integer) with Pre => Digit in 5 .. 15;

   procedure Component_Flag (Shut : Window) with Pre => Shut.Level > 0;
   procedure Component_Other (Left, Right : Window) with Pre => Left.Open;
   procedure Discriminants (Thin : Window)
     with Pre => Thin.Low <= Thin.High + 1;
   procedure Discriminant_Other (First, Second : Window)
     with Pre => First.Low < First.High;

   procedure Not_Known (Unknown : in out Window);
   procedure Declared_Constrained;
   procedure Declared_Subtype;
   procedure Other_Object (Free, Bound : in out Window)
     with Pre => not Free'Constrained;

   procedure Maybe_Null (Maybe : Cell);
   procedure Made_Null (Dropped : in out Cell) with Pre => Dropped /= null;
   procedure Other_Cell (Full, Empty : Cell) with Pre => Full /= null;

   procedure Other_Divisor (Rough : Natural) with Pre => Rough mod 4 = 0;

end Verification_Mutation_Expression_Forms;
