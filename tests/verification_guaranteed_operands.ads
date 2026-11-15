--  An operation of a type declared range L .. H is known not to overflow
--  when its result is within the part of the base range the language
--  guarantees and so is each operand that is an operation: here the
--  solvers prove both, the state knowing only the range of the type of
--  each product. GNATprove 16.1.0 proves every overflow check.
package Verification_Guaranteed_Operands with SPARK_Mode is

   type Millis is range 0 .. 86_399_999;

   subtype Hours is Natural range 0 .. 23;

   subtype Minutes is Natural range 0 .. 59;

   In_Hour : constant := 3_600_000;

   In_Minute : constant := 60_000;

   function Total (Hour : Hours; Minute : Minutes) return Millis;

end Verification_Guaranteed_Operands;
