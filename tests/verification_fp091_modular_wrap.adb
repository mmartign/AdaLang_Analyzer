--  FP-091: modular arithmetic wraps. 255 + 1 and 128 * 2 are 0 in a
--  "mod 256" type, so each division below can divide by zero; with a
--  divisor that cannot wrap to zero it still proves.
procedure Verification_FP091_Modular_Wrap
  (N    : Integer;
   Sink : out Integer)
with Pre => N in 0 .. 255
is
   type Byte is mod 256;

   Top    : constant Byte := 255;
   Half   : constant Byte := 128;
   Any    : constant Byte := Byte (N);
   Low    : constant Byte := 3;
   Result : Byte;
begin
   Result := 10 / (Top + 1);
   Result := 10 / (Half * 2);
   Result := 10 / (Any + 1);
   Sink := 10 / Integer (Any + 2);
   Sink := 10 / Integer (Any * 2 + 1);
   Result := 10 / (Low + 1);
   Sink := Sink + Integer (Result);
end Verification_FP091_Modular_Wrap;
