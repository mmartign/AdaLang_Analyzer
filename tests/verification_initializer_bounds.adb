--  An object of an unconstrained array subtype takes its bounds from its
--  initial value and keeps them. A string literal starts at the index
--  subtype's first value; another array object hands on its own bounds.
--  An object whose subtype has bounds of its own does not take the
--  initial value's.
procedure Verification_Initializer_Bounds
  (Given : String;
   Sink  : out Integer)
with
  SPARK_Mode
is
   subtype Five is String (11 .. 15);
   Word   : constant String := "abcd";
   Quoted : constant String := "a""b";
   Fixed  : constant String (3 .. 6) := "wxyz";
   Copy   : constant String := Fixed;
   Slid   : constant Five := "vwxyz";
   Taken  : constant String := Given;
begin
   Sink := Character'Pos (Word (4));
   Sink := Character'Pos (Word (5));
   Sink := Character'Pos (Quoted (3));
   Sink := Character'Pos (Quoted (2 + 2));
   Sink := Character'Pos (Copy (6));
   Sink := Character'Pos (Copy (2));
   Sink := Character'Pos (Slid (15));
   Sink := Character'Pos (Slid (1));
   Sink := Character'Pos (Taken (1 + 0));
end Verification_Initializer_Bounds;
