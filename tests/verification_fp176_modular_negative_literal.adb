--  FP-176: "-1" for a modular type is that type's "-": 16#FFFF_FFFF# for
--  Unsigned_32, 255 for Unsigned_8, not the integer -1. A branch under
--  "V = -1" is taken for that V, so the division by zero in it is a
--  definite error and not unreachable; "-1 + 1" wraps to a zero divisor;
--  "V /= -1" does not hold of every V. Mask, 255, is a divisor that
--  proves.
with Interfaces; use Interfaces;

procedure Verification_FP176_Modular_Negative_Literal
  (V    : Unsigned_32;
   B    : Unsigned_8;
   Sink : out Integer)
is
   Zero : constant Integer := 0;
   Last : constant Unsigned_32 := -1;
   Mask : constant Unsigned_8 := -(1);
begin
   Sink := 1;
   if V = -1 then
      Sink := 10 / Zero;
   end if;
   if B = Unsigned_8'(-1) then
      Sink := 20 / Zero;
   end if;
   Sink := 30 / Integer (Last + 1);
   Sink := 40 / Integer (Mask);
   pragma Assert (V /= -1);
end Verification_FP176_Modular_Negative_Literal;
