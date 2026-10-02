--  FP-088: an index or range check against bounds that no declaration
--  fixes must stay Unproved. Text, Table and Limit have bounds that depend
--  on the caller, so nothing below about them may be proved; Buffer and
--  Fixed carry their own static index constraint, so their checks are
--  decided either way.
procedure Verification_FP088_Unknown_Array_Bounds
  (Text     : String;
   Count    : Integer;
   Position : Integer;
   Sink     : out Integer)
with
  SPARK_Mode,
  Pre => Position >= 5
is
   type Dynamic is array (1 .. Count) of Integer;
   subtype Upto is Integer range 1 .. Count;
   subtype Line is String (1 .. 10);

   Table  : Dynamic := (others => 0);
   Buffer : String (1 .. 10) := (others => ' ');
   Fixed  : Line := (others => ' ');
   Limit  : Upto;
begin
   Sink := Character'Pos (Text (Position));
   Sink := Character'Pos (Text (2));
   Sink := Table (3);
   Limit := Position;
   pragma Assert (Text'First = 1);

   Sink := Character'Pos (Buffer (4));
   Sink := Character'Pos (Fixed (6));
   Sink := Character'Pos (Buffer (20));
   Sink := Character'Pos (Fixed (30));
   Sink := Sink + Limit;
end Verification_FP088_Unknown_Array_Bounds;
