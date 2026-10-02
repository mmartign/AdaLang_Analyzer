--  FP-089: two arbitrary Character values are not provably equal. The
--  placeholder declaration Libadalang gives Standard's character types has
--  a single literal, which must not be read as their value range. An
--  ordinary enumeration is still bounded by its own literals.
procedure Verification_FP089_Character_Positions
  (Left  : Character;
   Right : Character;
   Wide  : Wide_Character;
   Sink  : out Integer)
with SPARK_Mode
is
   type Colour is (Red, Green, Blue);
   Tint : constant Colour := Green;
begin
   Sink := 0;
   pragma Assert (Left = Right);
   pragma Assert (Left in Character);
   pragma Assert (Wide = Wide_Character'Val (65));
   if Left /= Right then
      Sink := 10 / Sink;
   end if;

   pragma Assert (Tint in Red .. Blue);
end Verification_FP089_Character_Positions;
