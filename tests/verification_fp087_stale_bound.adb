--  FP-087: a subtype or array bound is fixed when its declaration is
--  elaborated. Window and Slots read the variable Size, which is 10 at
--  that point; assigning Size afterwards must not widen them, so the two
--  checks that fail at run time below must not be proved. Frame and Cells
--  read a constant, so their checks still prove.
procedure Verification_FP087_Stale_Bound (Sink : out Integer)
with SPARK_Mode
is
   Size       : Integer := 10;
   Fixed_Size : constant Integer := 10;

   subtype Window is Integer range 1 .. Size;
   subtype Frame is Integer range 1 .. Fixed_Size;
   type Slots is array (1 .. Size) of Integer;
   type Cells is array (1 .. Fixed_Size) of Integer;

   Slot   : Slots := (others => 0);
   Cell   : Cells := (others => 0);
   Inside : Window;
   Framed : Frame;
begin
   Size := 100;
   Inside := 50;
   Sink := Slot (60);
   Framed := 7;
   Sink := Cell (8);
   Sink := Sink + Inside + Framed;
end Verification_FP087_Stale_Bound;
