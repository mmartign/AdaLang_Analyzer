--  Expression forms the scalar VC language takes: conditional and case
--  expressions, the components and the discriminants of a record, whether
--  a parameter is constrained, an access value compared with null, and a
--  divisor whose value is known. Every claim marked in the body holds; the
--  ones that do not are in Verification_Mutation_Expression_Forms.
package Verification_Expression_Forms with SPARK_Mode => On is

   type Kind is (Small, Medium, Large);

   type Window (Low : Natural := 0; High : Natural := 10) is record
      Open  : Boolean := False;
      Level : Natural := 0;
   end record;

   type Octet is mod 2 ** 8 with Size => 8;

   type Cell is access constant Integer;

   type Crate is record
      Inside : Cell;
      Weight : Natural := 0;
   end record;

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

   function Loaded (C : Crate) return Boolean is (C.Inside /= null);

   procedure Need_If (Up : Boolean; Amount : Integer)
     with Pre => (if Up then Amount > 5);
   procedure Need_Case (K : Kind; Amount : Integer)
     with Pre => (case K is when Small => Amount > 0, when others => Amount > 10);
   procedure Need_Open (W : Window) with Pre => W.Open;
   procedure Need_Span (W : Window) with Pre => W.Low <= W.High;
   procedure Refill (W : in out Window) with Pre => not W'Constrained;
   procedure Need_Cell (P : Cell) with Pre => P /= null;
   procedure Aligned (Bits : Natural) with Pre => Bits mod Octet'Size = 0;

   --  Conditional expressions.
   procedure If_Either (Flag : Boolean; Chosen : Integer)
     with Pre => Chosen > 7;
   procedure If_Function (Risen : Integer) with Pre => Risen > 0;
   procedure If_Negated (Sunk : Integer) with Pre => Sunk > 0;
   procedure If_Value (Any : Integer);
   procedure If_Chain (Product : Integer)
     with Pre => Product in -1_000 .. 1_000;

   --  Case expressions.
   procedure Case_Literal (Sized : Integer) with Pre => Sized > 20;
   procedure Case_Every (Which : Kind; Wide : Integer) with Pre => Wide > 20;
   procedure Case_Function (Shape : Kind; Roomy : Integer)
     with Pre => Roomy > 20;
   procedure Case_Chosen (Eleven : Integer) with Pre => Eleven = 11;
   procedure Case_Value (Given : Kind);

   --  Components and discriminants.
   procedure Component_Flag (Frame : Window)
     with Pre => Frame.Open and then Frame.Level > 0;
   procedure Discriminants (Span : Window) with Pre => Span.Low < Span.High;
   procedure Discriminant_Subtype (Based : Window);

   --  Whether an object is constrained.
   procedure Passed_On (Loose : in out Window)
     with Pre => not Loose'Constrained;
   procedure Passed_Twice (Twice : in out Window)
     with Pre => not Twice'Constrained;
   procedure Declared_Free;

   --  Access values and null.
   procedure Held_Cell (Held : Cell) with Pre => Held /= null;
   procedure Held_In_Record (Packed : Crate) with Pre => Loaded (Packed);

   --  A divisor that is known.
   procedure Known_Divisor (Whole : Natural)
     with Pre => Whole mod Octet'Size = 0;

end Verification_Expression_Forms;
