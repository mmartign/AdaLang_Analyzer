--  What verification_guaranteed_operands proves, where it does not hold:
--  minutes up to 100_000 take the sum past the guaranteed range.
--  GNATprove 16.1.0 refuses the overflow checks of the sum.
package Verification_Mutation_Guaranteed_Operands with SPARK_Mode is

   type Millis is range 0 .. 86_399_999;

   subtype Hours is Natural range 0 .. 23;

   In_Hour : constant := 3_600_000;

   In_Minute : constant := 60_000;

   function Total (Hour : Hours; Minute : Natural) return Millis
     with Pre => Minute <= 100_000;

end Verification_Mutation_Guaranteed_Operands;
