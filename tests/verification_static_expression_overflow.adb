--  An operation of a static expression is evaluated exactly, at compile
--  time: "2**63" in "-2**63" of an Integer_64 does not overflow (HAC's
--  bounds of Interfaces.Integer_64, FP-169). The same power of a variable
--  is evaluated at run time, in the base type, and overflows.
with Interfaces; use Interfaces;
procedure Verification_Static_Expression_Overflow
  (Lo, Hi, Big : out Integer_64)
is
   Two : constant Integer_64 := Integer_64 (Natural'(2));
   Base : Integer_64 := Two;
begin
   Lo := -2**63;
   Hi := 2**63 - 1;
   Big := Base ** 63;
end Verification_Static_Expression_Overflow;
